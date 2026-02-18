clear
clc
tStart = tic;

%% SCRIPT: Taller 1 - Confiabilidad Nivel Jerárquico I (Generación)
% Caso Base: 100% Generación Síncrona

% Sistema de prueba: IEEE RTS-24
% 32 generadores síncronos (sin condensador síncrono)
% Método: Monte Carlo Nivel I con truncamiento K≤2

%% PARÁMETROS CONFIGURABLES POR EL ESTUDIANTE
%  Modifique ÚNICAMENTE las variables de esta sección según el caso a evaluar.
%  No es necesario modificar ninguna otra parte del código.

% Demanda pico del sistema [MW]: 2850, 3075, 3300
p_max = 2850;

% Período de análisis: 1 = día, 0 = noche
dn = 1;

% Realizaciones objetivo de Monte Carlo
r_max = 500000;

% Error relativo máximo permitido
eps = 0.05;

% Graficar convergencia de E[DNS]: true / false
graficar = true;

%%  DATOS DE GENERACIÓN

% Capacidades de los 32 generadores originales [MW] (sin condensador síncrono)
Sn_ALL = [20; 20; 76; 76; 20; 20; 76; 76; 100; 100; 100; ...
          197; 197; 197; 12; 12; 12; 12; 12; 155; 155; ...
          400; 400; 50; 50; 50; 50; 50; 50; 155; 155; 350];

% FOR de los 32 generadores originales
FOR_ALL = [0.1; 0.1; 0.02; 0.02; 0.1; 0.1; 0.02; 0.02; 0.04; 0.04; 0.04; ...
           0.05; 0.05; 0.05; 0.02; 0.02; 0.02; 0.02; 0.02; 0.04; 0.04; ...
           0.12; 0.12; 0.01; 0.01; 0.01; 0.01; 0.01; 0.01; 0.04; 0.04; 0.08];

% Caso base: todos los generadores son síncronos
Sn_SYNC  = Sn_ALL;
FOR_SYNC = FOR_ALL;

% Sin fuentes renovables
typeFERNC = [];
Sn_FERNC  = [];
CM        = [];
VA        = 1;
Co_FERNC  = [];

%%  DEMANDA DEL SISTEMA

nombre_archivo = 'Carga.xlsx';
fp_original = 2850/sqrt(2850^2 + 580^2);
q_max = sqrt((p_max/fp_original)^2 - p_max^2);

[T_dia, T_noche, h_dia, h_noche] = Histograma_carga(nombre_archivo, p_max, q_max, 0);

if dn == 1
    LD = T_dia;  h_period = h_dia;  periodo_str = 'DIA';
else
    LD = T_noche; h_period = h_noche; periodo_str = 'NOCHE';
end

%% INFORMACIÓN DEL SISTEMA

Cap_total = sum(Sn_SYNC);
num_gen_sinc = length(Sn_SYNC);

% Espacio de estados con truncamiento K≤2
estados_N0 = 1;
estados_N1 = num_gen_sinc;
estados_N2 = nchoosek(num_gen_sinc, 2);
total_estados_gen = estados_N0 + estados_N1 + estados_N2;

fprintf('PROYECTO 1: CONFIABILIDAD NIVEL I (GENERACIÓN) - CASO BASE SÍNCRONO\n');
fprintf('  \n');
fprintf('  Sistema base: IEEE RTS-24\n');
fprintf('  Generadores síncronos: %d\n', num_gen_sinc);
fprintf('  Capacidad total: %.1f MW\n', Cap_total);
fprintf('  Demanda pico: %.1f MW\n', p_max);
fprintf('  Margen de reserva: %.1f MW (%.1f%%)\n\n', ...
    Cap_total - p_max, (Cap_total - p_max)/p_max*100);

fprintf('  Espacio de estados de generación (nivel I)\n\n');
fprintf('    Truncamiento: K ≤ 2 (máximo 2 generadores fallados)\n');
fprintf('      N-0: %d estado\n', estados_N0);
fprintf('      N-1: %d estados\n', estados_N1);
fprintf('      N-2: %d estados\n', estados_N2);
fprintf('      Total: %d estados\n', total_estados_gen);

fprintf('\n');
fprintf('DEMANDA DEL SISTEMA\n\n');
fprintf('  MODELADO PROBABILÍSTICO Y ESPACIO DE ESTADOS DE LA DEMANDA\n\n');
fprintf('    Estados de carga: %d\n', size(LD, 1));
fprintf('    Demanda pico: %.1f MW\n', p_max);
fprintf('    Factor de potencia: %.4f\n', fp_original);
fprintf('    Estados probabilísticos de carga:\n\n');
disp(LD);

%% EJECUCIÓN

factor_demanda = 1;

case_name = sprintf('HL-I_%s_%s_d%d_r%dk', ...
    'Base', periodo_str, p_max, round(r_max/1000));

res = SMC_Nivel1(Sn_SYNC, FOR_SYNC, ...
    typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_max, eps, LD, dn, case_name, h_period, ...
    factor_demanda);

tiempo_total = toc(tStart);
fprintf('Tiempo total del script: %.2f seg\n', tiempo_total);

%% GRÁFICA DE CONVERGENCIA

if graficar
    T = res.T_convergencia;
    n = T.Realizacion;
    media = T.Mean_DNS;
    se = T.Std_DNS ./ sqrt(n);

    % Bandas de confianza al 95%
    ci_sup = media + 1.96 * se;
    ci_inf = media - 1.96 * se;

    figure;
    hold on;
    fill([n; flipud(n)], [ci_sup; flipud(ci_inf)], ...
        [0.8 0.9 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
    plot(n, media, 'b-', 'LineWidth', 1.5);
    hold off;

    xlabel('Número de realizaciones');
    ylabel('E[DNS] [MW]');
    title(sprintf('Convergencia E[DNS] — %s, p_{max} = %d MW', periodo_str, p_max));
    legend('IC 95%', 'E[DNS]', 'Location', 'best');
    grid on;
end