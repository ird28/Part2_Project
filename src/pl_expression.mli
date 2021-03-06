(** Need some way of referring to locations for stores etc. *)
type loc = string

val string_of_loc : loc -> string

val random_loc : unit -> loc

type oper =
     Plus
   | Minus
   | Mult
   | Div
   | Mod
   | GT
   | LT
   | Equals
   | And
   | Or

type var_raw = string

type expr_raw =
     Integer_raw of int
   | Boolean_raw of bool
   | Not_raw of expr_raw
   | Op_raw of expr_raw * oper * expr_raw
   | If_raw of expr_raw * expr_raw * expr_raw
   | Assign_raw of expr_raw * expr_raw
   | Deref_raw of expr_raw
   | Ref_raw of expr_raw
   | Loc_raw of loc
   | Glo_raw of loc
   | Skip_raw
   | Seq_raw of expr_raw * expr_raw
   | While_raw of expr_raw * expr_raw
   | Var_raw of var_raw
   | Fn_raw of var_raw * expr_raw
   | App_raw of expr_raw * expr_raw
   | Let_raw of var_raw * expr_raw * expr_raw
   | Letrec_raw of var_raw * var_raw * expr_raw * expr_raw
   | Cas_raw of expr_raw * expr_raw * expr_raw
   | Spinlock_raw of loc
   | Lock_raw of expr_raw
   | Unlock_raw of expr_raw
   | Error_raw of string

(** Expressions with de Bruijn indices *)
type expr =
     Integer of int
   | Boolean of bool
   | Not of expr
   | Op of expr * oper * expr
   | If of expr * expr * expr
   | Assign of expr * expr
   | Deref of expr
   | Ref of expr
   | Loc of loc
   | Glo of loc
   | Skip
   | Seq of expr * expr
   | While of expr * expr
   | Var of int
   | Fn of expr
   | App of expr * expr
   | Let of expr * expr
   | Letrec of expr * expr
   | Cas of expr * expr * expr
   | Spinlock of loc
   | Lock of expr
   | Unlock of expr
   | Error of string

val convert_from_raw : expr_raw -> expr

(** Gives human-readable representation *)
val string_of_expr : expr -> string

(** Returns true iff expression represents error state *)
val is_error : expr -> bool

(** Returns true iff expression is a value *)
val is_value : expr -> bool

(** Returns global locations accessible *)
val locations_accessed : expr -> loc list

(** Substitutes first argument for outmost variable in second *)
val substitute_outmost : expr -> expr -> expr

(** Increments all indices at least the first argument in the second *)
val shift : int -> expr -> expr

(** Takes integer n and expression e, and swaps n and n+1 indices in e *)
val swap : int -> expr -> expr

