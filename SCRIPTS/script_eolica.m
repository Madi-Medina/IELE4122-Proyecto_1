clear
clc
tStart = tic;

%% SCRIPT: Taller 1 - Confiabilidad Nivel Jerárquico I (Generación)
% Caso con Generación Eólica

% Sistema de prueba: IEEE RTS-24
% 32 generadores originales: 23 permanecen síncronos, 9 se reemplazan por eólicos
% Método: Monte Carlo Nivel I con truncamiento K≤2

%% PARÁMETROS CONFIGURABLES POR EL ESTUDIANTE
%  Modifique ÚNICAMENTE las variables de esta sección según el caso a evaluar.
%  No es necesario modificar ninguna otra parte del código.

% Demanda pico del sistema [MW]: 2850, 3075, 3300
p_max = 2850;

% Período de análisis: 1 = día, 0 = noche
dn = 1;

% Multiplicador de capacidad renovable vs síncrona reemplazada: 1, 2, 3, ...
factor_cap = 1;

% Tipo de variables aleatorias FNCER: 0 = correlacionadas, 1 = independientes
VA = 1;

% Realizaciones objetivo de Monte Carlo
r_max = 500000;

% Error relativo máximo permitido
eps = 0.05;

%%  DATOS DE GENERACIÓN

% Capacidades de los 32 generadores originales [MW] (sin condensador síncrono)
Sn_ALL = [20; 20; 76; 76; 20; 20; 76; 76; 100; 100; 100; ...
          197; 197; 197; 12; 12; 12; 12; 12; 155; 155; ...
          400; 400; 50; 50; 50; 50; 50; 50; 155; 155; 350];

% FOR de los 32 generadores originales
FOR_ALL = [0.1; 0.1; 0.02; 0.02; 0.1; 0.1; 0.02; 0.02; 0.04; 0.04; 0.04; ...
           0.05; 0.05; 0.05; 0.02; 0.02; 0.02; 0.02; 0.02; 0.04; 0.04; ...
           0.12; 0.12; 0.01; 0.01; 0.01; 0.01; 0.01; 0.01; 0.04; 0.04; 0.08];

% gen_FNCER: 1 = síncrono, 0 = reemplazado por eólico
% Se reemplazan los generadores 3,4,7,8,20,21,30,31,32
gen_FNCER = [1;1;0;0;1;1;0;0;1;1;1;1;1;1;1;1;1;1;1;0;0;1;1;1;1;1;1;1;1;0;0;0];

% Filtrar: solo los que permanecen síncronos
Sn_SYNC  = Sn_ALL(gen_FNCER == 1);
FOR_SYNC = FOR_ALL(gen_FNCER == 1);

%%  FUENTES RENOVABLES (EÓLICA)

% Capacidad nominal de los generadores reemplazados [MW]
Sn = Sn_ALL(gen_FNCER == 0)';

% Parámetros Weibull por zona [a_dia, b_dia, a_noche, b_noche]
data_eolica_norte = [12 1.85 12 1.85];
data_eolica_sur   = [10 1.75 10 1.75];

% Turbina eólica
Sn_turbina = 2.750; % [MW]
c1 = 1:1:30;
c2 = 1/1000.*[0 0 0 17.8 118.4 257.8 447.3 693.2 997.7 1345 1708 2055.4 ...
              2349.8 2554.2 2667.4 2718.5 2738.2 2745.1 2747.3 2750 2750 ...
              2750 2750 2750 2750 0 0 0 0 0];
info_Turbina = [c1' c2'];

% Caracterización estadística (momentos centrales y capacidad efectiva)
[MC1, Sn_FNCER1] = Generacion_eolica(data_eolica_norte, Sn(1)*factor_cap, Sn_turbina, info_Turbina);
[MC2, Sn_FNCER2] = Generacion_eolica(data_eolica_norte, Sn(2)*factor_cap, Sn_turbina, info_Turbina);
[MC3, Sn_FNCER3] = Generacion_eolica(data_eolica_norte, Sn(3)*factor_cap, Sn_turbina, info_Turbina);
[MC4, Sn_FNCER4] = Generacion_eolica(data_eolica_norte, Sn(4)*factor_cap, Sn_turbina, info_Turbina);
[MC5, Sn_FNCER5] = Generacion_eolica(data_eolica_sur, Sn(5)*factor_cap, Sn_turbina, info_Turbina);
[MC6, Sn_FNCER6] = Generacion_eolica(data_eolica_sur, Sn(6)*factor_cap, Sn_turbina, info_Turbina);
[MC7, Sn_FNCER7] = Generacion_eolica(data_eolica_sur, Sn(7)*factor_cap, Sn_turbina, info_Turbina);
[MC8, Sn_FNCER8] = Generacion_eolica(data_eolica_sur, Sn(8)*factor_cap, Sn_turbina, info_Turbina);
[MC9, Sn_FNCER9] = Generacion_eolica(data_eolica_sur, Sn(9)*factor_cap, Sn_turbina, info_Turbina);

% Configuración PEM
typeFERNC = [1 1 1 1 1 1 1 1 1];
Sn_FERNC = [Sn_FNCER1 Sn_FNCER2 Sn_FNCER3 Sn_FNCER4 Sn_FNCER5 Sn_FNCER6 Sn_FNCER7 Sn_FNCER8 Sn_FNCER9];

idx_periodo = 2 - dn;

CM = [double(table2array(MC1(idx_periodo,2:end)))' double(table2array(MC2(idx_periodo,2:end)))' ...
      double(table2array(MC3(idx_periodo,2:end)))' double(table2array(MC4(idx_periodo,2:end)))' ...
      double(table2array(MC5(idx_periodo,2:end)))' double(table2array(MC6(idx_periodo,2:end)))' ...
      double(table2array(MC7(idx_periodo,2:end)))' double(table2array(MC8(idx_periodo,2:end)))' ...
      double(table2array(MC9(idx_periodo,2:end)))']; 

%        F1   F2   F3   F4   F5   F6   F7   F8   F9
Co_FERNC = [1    0.75 0.75 0.75 0.25 0.25 0.25 0.25 0.25;   % F1 Sur  (Bus 1)
            0.75 1    0.75 0.75 0.25 0.25 0.25 0.25 0.25;   % F2 Sur  (Bus 1)
            0.75 0.75 1    0.75 0.25 0.25 0.25 0.25 0.25;   % F3 Sur  (Bus 2)
            0.75 0.75 0.75 1    0.25 0.25 0.25 0.25 0.25;   % F4 Sur  (Bus 2)
            0.25 0.25 0.25 0.25 1    0.75 0.75 0.75 0.75;   % F5 Norte (Bus 15)
            0.25 0.25 0.25 0.25 0.75 1    0.75 0.75 0.75;   % F6 Norte (Bus 16)
            0.25 0.25 0.25 0.25 0.75 0.75 1    0.75 0.75;   % F7 Norte (Bus 23)
            0.25 0.25 0.25 0.25 0.75 0.75 0.75 1    0.75;   % F8 Norte (Bus 23)
            0.25 0.25 0.25 0.25 0.75 0.75 0.75 0.75 1   ];  % F9 Norte (Bus 23)

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

Cap_sincrona = sum(Sn_SYNC);
Cap_renovable = sum(Sn_FERNC);
Cap_sinc_removida = sum(Sn);
Cap_sinc_original = Cap_sincrona + Cap_sinc_removida;
Cap_total = Cap_sincrona + Cap_renovable;
num_gen_sinc = length(Sn_SYNC);

% Espacio de estados con truncamiento K≤2
estados_N0 = 1;
estados_N1 = length(Sn_SYNC);
estados_N2 = nchoosek(length(Sn_SYNC), 2);
total_estados_gen = estados_N0 + estados_N1 + estados_N2;

fprintf('PROYECTO 1: CONFIABILIDAD NIVEL I (GENERACIÓN) - GENERACIÓN EÓLICA DÍA\n');
fprintf('  \n');
fprintf('  Sistema base: IEEE RTS-24\n');
fprintf('  Capacidad síncrona original: %.1f MW\n\n', Cap_sinc_original);

fprintf('  Reemplazo de generación:\n');
fprintf('    Capacidad síncrona removida: %.1f MW\n', Cap_sinc_removida);
fprintf('    Capacidad renovable instalada: %.1f MW\n', Cap_renovable);
fprintf('    Factor de capacidad: x%.1f\n', factor_cap);
fprintf('    Sobredimensionamiento: %.1f MW (%.1fx)\n\n', ...
    Cap_renovable - Cap_sinc_removida, Cap_renovable/Cap_sinc_removida);

fprintf('  Sistema final:\n');
fprintf('    Generadores totales: %d (%d síncronos + %d eólicos)\n', ...
    length(gen_FNCER), num_gen_sinc, sum(gen_FNCER == 0));
fprintf('    Capacidad síncrona: %.1f MW (%.1f%%)\n', Cap_sincrona, Cap_sincrona/Cap_total*100);
fprintf('    Capacidad renovable: %.1f MW (%.1f%%)\n', Cap_renovable, Cap_renovable/Cap_total*100);
fprintf('    Capacidad total: %.1f MW\n', Cap_total);

fprintf('\n');
fprintf('  Espacio de estados de generación (nivel I)\n\n');
fprintf('    Truncamiento: K ≤ 2 (máximo 2 generadores fallados)\n');
fprintf('      N-0: %d estado\n', estados_N0);
fprintf('      N-1: %d estados\n', estados_N1);
fprintf('      N-2: %d estados\n', estados_N2);
fprintf('      Total: %d estados\n', total_estados_gen);

fprintf('\n');
fprintf('FUENTES RENOVABLES NO CONVENCIONALES (FNCER)\n\n');
fprintf('  MODELADO PROBABILÍSTICO DE LAS FUENTES RENOVABLES (EÓLICA)\n\n');

fprintf('    Parámetros Weibull zona norte:\n');
fprintf('      Día: a = %.2f m/s, b = %.2f\n', data_eolica_norte(1), data_eolica_norte(2));
fprintf('      Noche: a = %.2f m/s, b = %.2f\n', data_eolica_norte(3), data_eolica_norte(4));
fprintf('    Parámetros Weibull zona sur:\n');
fprintf('      Día: a = %.2f m/s, b = %.2f\n', data_eolica_sur(1), data_eolica_sur(2));
fprintf('      Noche: a = %.2f m/s, b = %.2f\n\n', data_eolica_sur(3), data_eolica_sur(4));

fprintf('    Caracterización de la potencia disponible por las fuentes eólicas:\n\n');

datos_parques = zeros(length(Sn_FERNC), 5);
for i = 1:length(Sn_FERNC)
    datos_parques(i, :) = [Sn_FERNC(i), CM(1,i), CM(2,i), CM(3,i), CM(4,i)];
end
nombres_parques = cell(length(Sn_FERNC), 1);
for i = 1:length(Sn_FERNC)
    nombres_parques{i} = sprintf('F%d', i);
end
tabla_parques = array2table(datos_parques, ...
    'VariableNames', {'Pnom [MW]', 'Media [MW]', 'Desv [MW]', 'Sesgo', 'Curtosis'});
tabla_parques = addvars(tabla_parques, categorical(nombres_parques), ...
    'Before', 'Pnom [MW]', 'NewVariableNames', 'Fuente');
disp(tabla_parques);

fprintf('  ESPACIO DE ESTADOS DE LAS FNCER (PEM 2m+1):\n\n');

[~, ~, pc] = PEM(typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, dn);

fprintf('    Método: Point Estimate Method (PEM 2m+1)\n');
fprintf('    Fuentes modeladas (m): %d\n', length(typeFERNC));
if VA == 0
    fprintf('    Variables correlacionadas\n');
else
    fprintf('    Variables independientes\n');
end
fprintf('    Puntos de concentración: %d\n\n', size(pc, 1));

num_fuentes = size(pc, 2) - 2;
potencia_total = sum(pc(:, 2:end-1), 2);
matriz_pem = [pc(:, 1), pc(:, 2:end-1), potencia_total, pc(:, end)];
var_names = {'Punto'};
for i = 1:num_fuentes
    var_names{end+1} = sprintf('F%d [MW]', i);
end
var_names{end+1} = 'Agregado [MW]';
var_names{end+1} = 'Peso';
tabla_pem = array2table(matriz_pem, 'VariableNames', var_names);
fprintf('    Tabla de escenarios PEM:\n\n');
disp(tabla_pem);

fprintf('DEMANDA DEL SISTEMA\n\n');
fprintf('  MODELADO PROBABILÍSTICO Y ESPACIO DE ESTADOS DE LA DEMANDA\n\n');
fprintf('    Estados de carga: %d\n', size(LD, 1));
fprintf('    Demanda pico: %.1f MW\n', p_max);
fprintf('    Factor de potencia: %.4f\n', fp_original);
fprintf('    Estados probabilísticos de carga:\n\n');
disp(LD);

%% PARÁMETROS DE ANÁLISIS

factor_demanda = 1;


%% EJECUCIÓN

if VA == 1
    va_str = '_VAind';
else
    va_str = '_VAcorr';
end

case_name = sprintf('HL-I_%s_%s_fc%d_d%d_r%dk%s', ...
    'Eolica', periodo_str, factor_cap, p_max, round(r_max/1000), va_str);

res = SMC_Nivel1(Sn_SYNC, FOR_SYNC, ...
    typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_max, eps, LD, dn, case_name, h_period, ...
    factor_demanda);

tiempo_total = toc(tStart);
fprintf('Tiempo total del script: %.2f seg\n', tiempo_total);