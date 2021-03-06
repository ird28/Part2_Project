%% importing data
transitions = dlmread('t43_tpl2_ops1.csv', ',', 0, 0);
ss = dlmread('ss21_trans.csv', ',', 0, 0);
ssthreads = [1:13];
% convert 0 values to NaNs, as these don't plot
transitions(transitions==0)=nan;
threads = [1:20];

%% plotting lines

semilogy(threads, transitions(:, 1), 'ko-')
hold on
semilogy(ssthreads, ss, 'kx-')
semilogy(threads, transitions(:, 3), 'ks-')
semilogy(threads, transitions(:, 4), 'bo-')
semilogy(threads, transitions(:, 5), 'bx-')
semilogy(threads, transitions(:, 6), 'bs-')
semilogy(threads, transitions(:, 7), 'rx-')
semilogy(threads, transitions(:, 8), 'rs-')
hold off
grid on

%% adding axis labels
ax = gca;
set(ax, 'FontName', 'Palatino Linotype', 'FontSize', 14);
xlabel('Number of Threads');
ylabel('Number of Transitions');
axis([0 20 1 100000000])
ax.YTick = [1 100 10000 1000000 100000000];

%% output pdf file
h = figure(1);
h.Units = 'centimeters'; % set figure position to cm
%h.Position(2) = [h.Position(2)-9]; % set figure position bevore resize
h.Position([3:4]) = [10,7]; % resize figure
Plot2LaTeX( h, 't43_tpl2_ops1' )