module ExpImp = Pl_expression
module StoreImp = Store.PLStore

open Pl_expression (* Allows e.g. Integer to be accessed *)

type step = { new_expr : ExpImp.expr ;
              s_update : StoreImp.store_update option ;
              g_update : StoreImp.store_update option ;
              g_loc    : ExpImp.loc option ;
            }

type transition = { next_expr : ExpImp.expr ;
                    s_updates : StoreImp.store ;
                    g_updates : StoreImp.store ;
                    g_loc     : ExpImp.loc ;
                  }

let string_of_transition t =
    "next_expr: " ^ (ExpImp.string_of_expr t.next_expr) ^ "\n" ^
    "s_updates: " ^ (StoreImp.string_of_store t.s_updates) ^ "\n" ^
    "g_updates: " ^ (StoreImp.string_of_store t.g_updates) ^ "\n" ^
    "g_loc:     " ^ (ExpImp.string_of_loc t.g_loc) ^ "\n"

(* next_step_aux : (expr * store * store)
     -> (expr * store_update * store_update * ((loc * bool) option)*)
(* Given expression, local store, global store, gives next thread step if it exists *)
(* Note the (loc * bool) option is the global location accessed and whether the step
   is enabled. The step enabled bool is there because it was an easy change to make,
   not because it is logically strongly related to the global location accessed*)
let rec next_step_aux (e, s, g)  = match e with
    Integer _ -> None
  | Boolean _ -> None
  | Not (Boolean b) -> Some (Boolean (not b), None, None, None)
  | Not e1 -> (match next_step_aux (e1, s, g) with
                Some (f, t, h, lo) -> Some(Not f, t, h, lo)
              | None -> None)
  | Op (Integer n, Plus, Integer m) -> Some (Integer (n+m), None, None, None)
  | Op (Integer n, Minus, Integer m) -> Some (Integer (n-m), None, None, None)
  | Op (Integer n, Mult, Integer m) -> Some (Integer (n*m), None, None, None)
  | Op (Integer n, Div, Integer m) -> Some (Integer (n/m), None, None, None)
  | Op (Integer n, Mod, Integer m) -> Some (Integer (n mod m), None, None, None)
  | Op (Integer n, GT, Integer m) -> Some (Boolean (n > m), None, None, None)
  | Op (Integer n, LT, Integer m) -> Some (Boolean (n < m), None, None, None)
  | Op (Integer n, Equals, Integer m) -> Some (Boolean (n = m), None, None, None)
  | Op (Boolean x, Equals, Boolean y) -> Some (Boolean (x = y), None, None, None)
  | Op (Boolean x, And, Boolean y) -> Some (Boolean (x && y), None, None, None)
  | Op (Boolean x, Or, Boolean y) -> Some (Boolean (x || y), None, None, None)
  | Op (e1, op, e2) -> (if is_value e1 then
                        match next_step_aux (e2, s, g) with
                            Some (f, t, h, lo) -> Some (Op (e1, op, f), t, h, lo)
                          | None -> None
                       else
                        match next_step_aux (e1, s, g) with
                            Some (f, t, h, lo) -> Some (Op (f, op, e2), t, h, lo)
                          | None -> None)
  | If (e1, e2, e3) -> (match e1 with
                        Boolean b -> if b then Some (e2, None, None, None) else Some (e3, None, None, None)
                      | _ -> match next_step_aux (e1, s, g) with
                            Some (f, t, h, lo) -> Some (If (f, e2, e3), t, h, lo)
                          | None -> None)
  | Assign (Loc l, e2) -> if is_value e2 then Some (Skip, Some (l, e2), None, None) else
                            (match next_step_aux (e2, s, g) with
                                Some (f, t, h, lo) -> Some (Assign (Loc l, f), t, h, lo)
                              | None -> None)
  | Assign (e1, e2) -> (match next_step_aux (e1, s, g) with (* e1 not a location so reduce *)
                        Some (f, t, h, lo) -> Some (Assign (f, e2), t, h, lo)
                      | None -> None)
  | Deref (Loc l) -> (match StoreImp.get s l with
                        Some v -> Some (v, None, None, None)
                      | None -> None)
  | Deref (Glo l) -> (match StoreImp.get g l with
                        Some v -> Some (v, None, None, Some (l, true))
                      | None -> None)
  | Deref e1 -> (match next_step_aux (e1, s, g) with
                    Some (f, t, h, lo) -> Some (Deref f, t, h, lo)
                  | None -> None)
  | Ref e1 -> if is_value e1 then
                    let fl = StoreImp.get_fresh_loc s in Some (Loc fl, Some (fl, e1), None, None)
                else (match next_step_aux (e1, s, g) with
                        Some (f, t, h, lo) -> Some (Ref f, t, h, lo)
                      | None -> None)
  | Loc _ -> None
  | Glo _ -> None
  | Skip -> None
  | Seq (Skip, e2) -> Some (e2, None, None, None)
  | Seq (e1, e2) -> (match next_step_aux (e1, s, g) with
                        Some (f, t, h, lo) -> Some (Seq (f, e2), t, h, lo)
                      | None -> None)
  | While (e1, e2) -> Some (If (e1, Seq (e2, While (e1, e2)), Skip), None, None, None)
  | Fn (_) -> None
  | App (Fn (e1), e2) -> if is_value e2 then
                            Some (substitute_outmost e2 e1, None, None, None)
                        else (match next_step_aux (e2, s, g) with
                            Some (f, t, h, lo) -> Some (App (Fn (e1), f), t, h, lo)
                          | None -> None)
  | App (e1, e2) -> (match next_step_aux (e1, s, g) with
                        Some (f, t, h, lo) -> Some (App (f, e2), t, h, lo)
                      | None -> None)
  | Var _ -> None
  | Let (e1, e2) -> if is_value e1 then Some (substitute_outmost e1 e2, None, None, None)
                        else (match next_step_aux (e1, s, g) with
                            Some (f, t, h, lo) -> Some (Let (f, e2), t, h, lo)
                          | None -> None)
  | Letrec (e1, e2) -> (* Need to adjust de Bruijn indices as new binding contexts for e1 *)
      Some (substitute_outmost (Fn (Letrec (shift 2 e1, swap 0 e1))) e2, None, None, None)
  | Cas (Glo l, e2, e3) -> if is_value e2 then (* Reduce e1 then e2 then e3 to values *)
                            (if is_value e3 then (match StoreImp.get g l with
                                Some v -> if v = e2 then Some (Boolean true, None, Some (l, e3), Some (l, true))
                                             else Some (Boolean false, None, None, Some (l, true))
                              | None -> None)
                            else (match next_step_aux (e3, s, g) with
                             Some (f, t, h, lo) -> Some (Cas (Glo l, e2, f), t, h, lo)
                           | None -> None))
                           else (match next_step_aux (e2, s, g) with
                            Some (f, t, h, lo) -> Some (Cas (Glo l, f, e3), t, h, lo)
                          | None -> None)
  | Cas (e1, e2, e3) -> (match next_step_aux (e1, s, g) with
                            Some (f, t, h, lo) -> Some (Cas (f, e2, e3), t, h, lo)
                          | None -> None)
  | Spinlock _ -> None
  | Lock (Spinlock l) -> (match StoreImp.get g l with
                            Some (Boolean b) ->
                                (* Move to Skip is next, but enabled iff not b *)
                                Some (Skip, None, Some (l, Boolean true), Some (l, not b))
                          | Some _ -> raise (Failure "A lock has a non-Boolean value; oh dear")
                          | None -> raise (Failure "A non-existent lock cannot be locked"))
  | Lock e1 -> (match next_step_aux (e1, s, g) with
                    Some (f, t, h, lo) -> Some (Lock f, t, h, lo)
                  | None -> None)
  | Unlock (Spinlock l) -> (match StoreImp.get g l with
                            Some v -> if v = Boolean true then
                                Some (Skip, None, Some (l, Boolean false), Some (l, true))
                                 else raise (Failure ("Cannot unlock with value "
                                    ^ ExpImp.string_of_expr v))
                          | None -> raise (Failure "Cannot unlock nonexistent lock"))
  | Unlock e1 -> (match next_step_aux (e1, s, g) with
                    Some (f, t, h, lo) -> Some (Unlock f, t, h, lo)
                  | None -> None)
  | Error msg -> None

let next_step x = match next_step_aux x with
    Some (f, t, h, lo) -> (match lo with Some (l, b) ->
                              Some ({ new_expr = f;
                                     s_update = t;
                                     g_update = h;
                                     g_loc = Some l;
                                   }, b)
                          | None ->
                              Some ({ new_expr = f;
                                     s_update = t;
                                     g_update = h;
                                     g_loc = None;
                                   }, true))
  | None -> None

(* next_transition_aux : expr * store * store -> (expr * store * store * loc * bool) option *)
(* Given expression, local state and global state, gives new expression
* local store update, global store update,global location touched, and enabled bool *)
let rec next_transition_aux (e, s, g) =
    (* If opt is None then empty, else if Some su then just [su] *)
    let extract opt = match opt with
        Some su -> StoreImp.update StoreImp.empty su
      | None -> StoreImp.empty
    in match next_step_aux (e, s, g) with
        Some (f, t, h, lo) -> (match lo with
            (* Global object touched: transition just this step *)
            Some (l, b) -> Some (f, extract t, extract h, l, b)
            (* No global object touched: this step plus subsequent ones *)
          | None -> (match next_transition_aux (f, StoreImp.extend s (extract t), g) with
                (* There is some recursive result; construct our result *)
                Some (e_res, s_res, g_res, l_res, b_res) ->
                    (* Need to add our local store updates if not overriden *)
                    Some (e_res, (match t with None -> s_res | Some su -> s_res @ [su]),
                             g_res, l_res, b_res)
                (* Stuck so no transition *)
              | None -> None))
      (* No next step so no transition *)
      | None -> None

let next_transition x = match next_transition_aux x with
    Some (f, t, h, gl, enabled) -> Some ({ next_expr = f;
                                 s_updates = StoreImp.minimise t;
                                 g_updates = StoreImp.minimise h;
                                 g_loc = gl;
                               }, enabled)
  | None -> None

(* Returns pair of bools.
    First is true iff an error is reached.
    Second is true iff it stops at a non-value *)
let rec check_local (ex, st, g) =
    if ExpImp.is_error ex
    then (true, false)
    else match next_step (ex, st, g) with
        None -> (false, not (ExpImp.is_value ex))
      | Some (t_step, enabled) -> if not enabled then
                raise (Failure "Should always be enabled") else
                    (check_local (t_step.new_expr,
                        (match t_step.s_update with
                          None -> st
                        | Some su -> StoreImp.update st su), g))
