function [resultados] = SMC_Nivel1(Sn_SYNC, FOR_SYNC, typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, r, eps, LD, dn, case_name, h_period, factor_demanda)
% Evalúa confiabilidad mediante Monte Carlo Nivel I (solo generación)

% Recibe:
%   Sn_SYNC: capacidades nominales de generadores síncronos [MW]. Type: vector (nx1) double.
%   FOR_SYNC: probabilidades de falla (FOR) de generadores síncronos. Type: vector (nx1) double.
%   typeFERNC: tipo de cada fuente renovable (1=eólica, 2=solar). Type: vector (mx1) double.
%   Sn_FERNC: capacidad nominal de cada fuente renovable [MW]. Type: vector (mx1) double.
%   CM: momentos centrales de las fuentes renovables. Type: matrix (4xm) double.
%   VA: tipo de variables aleatorias (1=independientes, 0=correlacionadas). Type: double.
%   Co_FERNC: matriz de correlación entre fuentes renovables. Type: matrix (mxm) double.
%   r: número de realizaciones objetivo. Type: double.
%   eps: error máximo permitido (0.05 = 5%). Type: double.
%   LD: tabla de estados de carga probabilísticos. Type: table.
%   dn: período (1=día, 0=noche). Type: double.
%   case_name: nombre para guardar resultados ('' = no guardar). Type: string.
%   h_period: horas del período en el año [horas]. Type: double.
%   factor_demanda: factor multiplicativo de demanda, 1.0=base. Type: double.

% Retorna:
%   resultados: struct con índices de confiabilidad, tiempos y configuración.

fprintf('  SIMULACIÓN DE MONTECARLO NIVEL JERÁRQUICO I (SOLO GENERACIÓN) \n');
fprintf('\n');

% Validación de parámetros opcionales
if nargin < 14 || isempty(factor_demanda), factor_demanda = 1.0; end

% Asegurar vectores fila
Sn_SYNC = Sn_SYNC(:)';
FOR_SYNC = FOR_SYNC(:)';
No_SYNC = length(Sn_SYNC);

fprintf('    Configuración\n\n');
fprintf('      Realizaciones obj.: %d\n', r);
fprintf('      Error objetivo:     %.1f%%\n\n', eps*100);

% Verificación de caché de resultados previos

if nargin >= 12 && ~isempty(case_name)
    filename = sprintf('%s.mat', case_name);
    
    if exist(filename, 'file')
        fprintf('    Resultados desde caché\n\n');
        data = load(filename);
        resultados = data.mc_results.resultados;
        
        resultados.LOLP = resultados.LOLP * (8760 / h_period);  % deshace el bug
        resultados.LOLE = resultados.LOLP * h_period;
        
        fprintf('      E[DNS]: %.4f MW\n', resultados.E_DNS);
        fprintf('      LOLP: %.6f (%.4f%%)\n', resultados.LOLP, resultados.LOLP*100);
        fprintf('      LOLE: %.4f horas/año\n', resultados.LOLE);
        fprintf('      LOEE: %.4f MWh/año\n', resultados.LOEE);
        fprintf('      Error: %.2f%%\n', resultados.error*100);
        fprintf('      Realizaciones: %d\n', resultados.num_simulaciones);
        fprintf('      Tiempo: %.2f min\n\n', resultados.tiempos.total_min);

        fprintf('Cargado desde: %s\n\n', filename);
        return;
    end
    tic_start = tic;
else
    case_name = '';
    tic_start = tic;
end

% Inicialización del sistema de caché global

tic_setup = tic;

cache_file = sprintf('cache_%s.mat', case_name);
total_hits = 0;
total_misses = 0;

if exist(cache_file, 'file')
    fprintf('    Cargando caché global...\n');
    cache_data = load(cache_file);
    cache_global = cache_data.cache_dns;
    fprintf('    * %d casos en caché\n', length(cache_global.keys));
    fprintf('  \n');

    cache_keys = keys(cache_global);
    cache_values = values(cache_global);
    cache_struct = struct();
    for i = 1:length(cache_keys)
        cache_struct.(['k_' strrep(cache_keys{i}, '-', '_')]) = cache_values{i};
    end
else
    fprintf('    Iniciando sin caché previo\n');
    fprintf('    \n');
    cache_global = containers.Map('KeyType', 'char', 'ValueType', 'double');
    cache_struct = struct();
end

% Configuración de procesamiento

% poolobj = gcp('nocreate');
% 
% if isempty(poolobj)
%     numcores = feature('numcores');
%     cores_to_use = max(1, min(round(numcores * 0.75), 16));
%     poolobj = parpool('Processes', cores_to_use, 'SpmdEnabled', false);
% else
%     cores_to_use = poolobj.NumWorkers;
% end
% 
% batch_size = cores_to_use * 500;

cores_to_use = 1;
batch_size = 500;

% Espacio de estados con truncamiento K≤2
estados_N0 = 1;
estados_N1 = No_SYNC;
estados_N2 = nchoosek(No_SYNC, 2);
total_estados_gen = estados_N0 + estados_N1 + estados_N2;

% Preparación de datos de demanda

if istable(LD)
    Load_MW_base = table2array(LD(:, 3));
    Prob_Acum = table2array(LD(:, 6));
    num_estados_carga = length(Load_MW_base);
    usar_tabla = true;
    Prob_Individual = diff([0; Prob_Acum]);
elseif size(LD, 1) > 1 && size(LD, 2) >= 3
    Load_MW_base = LD(:, 1);
    Prob_Acum = LD(:, 3);
    num_estados_carga = length(Load_MW_base);
    usar_tabla = true;
    Prob_Individual = diff([0; Prob_Acum]);
else
    Load_MW_base = LD;
    num_estados_carga = 1;
    usar_tabla = false;
    Prob_Individual = 1;
end

Load_MW = Load_MW_base * factor_demanda;
L = sum(Load_MW .* Prob_Individual);

if factor_demanda ~= 1.0
    fprintf('    ESTRÉS DE DEMANDA: pico original %.1f MW -> %.1f MW (x%.2f)\n\n', ...
        max(Load_MW_base), max(Load_MW), factor_demanda);
end

% Puntos de concentración para fuentes renovables
if ~isempty(typeFERNC)
    [~, ~, pc] = PEM(typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, dn);
    len = size(pc, 1);
else
    len = 0;
    pc = [];
end

t_setup = toc(tic_setup);

% Simulación Monte Carlo

fprintf('    INICIANDO SIMULACIÓN NIVEL I\n\n');
tic_sim = tic;

cont_mcs = 0; sum_DNS = 0; sum_DNS2 = 0; error_DNS = 1;
MCS = []; rechazados = 0; num_fallas_total = 0;

max_intentos = round(r * 1.2);
rand_carga = rand(max_intentos, 1);
rand_gen = rand(max_intentos, No_SYNC);
intento_actual = 0;

while cont_mcs < r && error_DNS >= eps
    
    % Construcción del lote
    batch_data = []; batch_count = 0;
    
    while batch_count < batch_size && intento_actual < max_intentos && cont_mcs + batch_count < r
        intento_actual = intento_actual + 1;
        
        u_load = rand_carga(intento_actual);
        valores_gen = rand_gen(intento_actual, :)';
        
        if usar_tabla
            idx_carga = find(u_load <= Prob_Acum, 1);
            if isempty(idx_carga), idx_carga = num_estados_carga; end
            L_actual = Load_MW(idx_carga);
        else
            idx_carga = 1;
            L_actual = Load_MW;
        end
        
        gen_fallados = valores_gen <= FOR_SYNC';
        if sum(gen_fallados) > 2
            rechazados = rechazados + 1;
            continue;
        end
        
        batch_count = batch_count + 1;
        batch_data(batch_count).idx_carga = idx_carga;
        batch_data(batch_count).gen_fallados = gen_fallados;
        batch_data(batch_count).L_actual = L_actual;
        batch_data(batch_count).Sn_SYNC = Sn_SYNC;
    end
    
    if batch_count == 0
        rand_carga = rand(max_intentos, 1);
        rand_gen = rand(max_intentos, No_SYNC);
        intento_actual = 0;
        continue;
    end
    
    % Procesamiento del lote
    pc_shared = pc; len_shared = len;
    cache_struct_local = cache_struct;
    
    batch_DNS = zeros(batch_count, 1);
    batch_new_cache = cell(batch_count, 1);
    batch_stats = zeros(batch_count, 2);
    
    
    %parfor b = 1:batch_count
    for b = 1:batch_count
        [batch_DNS(b), batch_new_cache{b}, batch_stats(b,:)] = ...
            calcular_dns_escenario(batch_data(b), dn, pc_shared, len_shared, ...
            true, cache_struct_local);
    end


    % Consolidación de caché
    
    for b = 1:batch_count
        if ~isempty(batch_new_cache{b})
            new_keys = keys(batch_new_cache{b});
            for k = 1:length(new_keys)
                if ~cache_global.isKey(new_keys{k})
                    cache_global(new_keys{k}) = batch_new_cache{b}(new_keys{k});
                    key_safe = ['k_' strrep(new_keys{k}, '-', '_')];
                    cache_struct.(key_safe) = batch_new_cache{b}(new_keys{k});
                end
            end
        end
    end
    
    
    % Acumulación de estadísticas
    for b = 1:batch_count
        cont_mcs = cont_mcs + 1;
        DNS_actual = batch_DNS(b);
        
        if DNS_actual > 0, num_fallas_total = num_fallas_total + 1; end
        
        sum_DNS = sum_DNS + DNS_actual;
        sum_DNS2 = sum_DNS2 + DNS_actual^2;
        
        if size(MCS, 1) < cont_mcs, MCS(cont_mcs, :) = zeros(1, 5); end
        MCS(cont_mcs, 1) = cont_mcs;
        MCS(cont_mcs, 2) = DNS_actual;
        
        if cont_mcs > 1
            mean_DNS = sum_DNS / cont_mcs;
            var_DNS = (sum_DNS2 - sum_DNS^2/cont_mcs) / (cont_mcs - 1);
            std_DNS = sqrt(max(0, var_DNS));
            se_DNS = std_DNS / sqrt(cont_mcs);
            
            if mean_DNS > 0
                error_DNS = (1.96 * se_DNS) / mean_DNS;
            else
                error_DNS = 1;
            end
            if isnan(error_DNS) || isinf(error_DNS), error_DNS = 1; end
            
            MCS(cont_mcs, 3) = mean_DNS;
            MCS(cont_mcs, 4) = std_DNS;
            MCS(cont_mcs, 5) = error_DNS;
        end
    end
    
    total_hits = total_hits + sum(batch_stats(:, 1));
    total_misses = total_misses + sum(batch_stats(:, 2));
    
    % Progreso
    if mod(cont_mcs, 10000) == 0 || cont_mcs == 100
        tiempo_actual = toc(tic_start);
        vel = cont_mcs / (tiempo_actual/60);
        eta = (r - cont_mcs) / vel;
        
        if (total_hits + total_misses) > 0
            hit_rate = total_hits / (total_hits + total_misses) * 100;
            fprintf('      Iter %6d: E[DNS]=%.4f MW, Error=%.2f%%, Hit=%.0f%%, Vel=%.0f real/min, ETA=%.1f min\n', ...
                    cont_mcs, mean_DNS, error_DNS*100, hit_rate, vel, eta);
        else
            fprintf('      Iter %6d: E[DNS]=%.4f MW, Error=%.2f%%, Vel=%.0f real/min, ETA=%.1f min\n', ...
                    cont_mcs, mean_DNS, error_DNS*100, vel, eta);
        end
    end
    
    % Checkpoint
    if mod(cont_mcs, 50000) == 0
        fprintf('        \n');
        fprintf('        Guardando checkpoint (%d realizaciones)...\n', cont_mcs);
        fprintf('        \n');
        cache_dns = cache_global;
        save(cache_file, 'cache_dns', '-v7.3');
    end
end

t_sim = toc(tic_sim);

% Cálculo de índices finales

tic_post = tic;

T_convergencia = array2table(MCS(1:cont_mcs, :));
T_convergencia.Properties.VariableNames = {'Realizacion', 'DNS', 'Mean_DNS', 'Std_DNS', 'Error'};

E_DNS = sum_DNS / cont_mcs;
des_DNS = sqrt(max(0, (sum_DNS2 - sum_DNS^2/cont_mcs) / (cont_mcs - 1)));
LOLP = num_fallas_total / cont_mcs;   % Probabilidad de déficit en el período
LOLE = LOLP * h_period;               % Horas esperadas de pérdida [h/año-período]
LOEE = E_DNS * h_period;              % Energía no suministrada [MWh/año-período]
error_DNS = MCS(cont_mcs, 5);

t_post = toc(tic_post);
t_total = toc(tic_start);

% Estructura de resultados

resultados = struct();
resultados.L = L;
resultados.E_DNS = E_DNS;
resultados.std_DNS = des_DNS;
resultados.LOLP = LOLP;
resultados.LOLE = LOLE;
resultados.LOEE = LOEE;
resultados.error = error_DNS;
resultados.num_simulaciones = cont_mcs;
resultados.rechazados = rechazados;
resultados.T_convergencia = T_convergencia;

resultados.tiempos = struct('setup_seg', t_setup, 'simulacion_seg', t_sim, ...
    'postproceso_seg', t_post, 'total_seg', t_total, 'total_min', t_total/60, ...
    'velocidad_real_por_min', cont_mcs/(t_total/60));

resultados.config = struct('factor_demanda', factor_demanda, ...
    'cores', cores_to_use, 'r_objetivo', r, 'eps_objetivo', eps, ...
    'h_period', h_period, 'con_renovables', ~isempty(typeFERNC), ...
    'No_SYNC', No_SYNC, 'total_estados_gen', total_estados_gen);

resultados.cache_stats = struct('hits', total_hits, 'misses', total_misses, ...
    'hit_rate', total_hits/(total_hits+total_misses)*100, ...
    'unique_cases', length(cache_global.keys));

% Impresión de resultados
fprintf('    \n');
fprintf('    RESULTADOS FINALES\n\n');
fprintf('      E[DNS]: %.4f MW\n', E_DNS);
fprintf('      σ[DNS]: %.4f MW\n', des_DNS);
fprintf('      LOLP: %.6f (%.4f%%)\n', LOLP, LOLP*100);
fprintf('      LOLE: %.4f horas/año\n', LOLE);
fprintf('      LOEE: %.4f MWh/año\n', LOEE);
fprintf('      Error: %.2f%%\n\n', error_DNS*100);

fprintf('      Realizaciones: %d\n', cont_mcs);
fprintf('      Rechazados (K>2): %d (%.1f%%)\n', rechazados, rechazados/(cont_mcs+rechazados)*100);
fprintf('      Tiempo: %.2f seg (%.2f min)\n', t_total, t_total/60);

% Guardado

if ~isempty(case_name)
    mc_results = struct('resultados', resultados, 'timestamp', datestr(now));
    filename = sprintf('%s.mat', case_name);
    save(filename, 'mc_results', '-v7.3');
    fprintf('\n');
    fprintf('Guardado: %s\n', filename);
    
    cache_dns = cache_global;
    save(cache_file, 'cache_dns', '-v7.3');
    fprintf('\n');
end

end