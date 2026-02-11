function [DNS_w, local_cache, stats] = calcular_dns_escenario(data, dn, pc, len, usar_cache, cache_struct)
% Calcula la Demanda No Suministrada (DNS) ponderada para un escenario
% de generación dado, considerando fuentes síncronas y renovables (PEM).

% Recibe:
%   data: struct con los datos del escenario. Campos:
%         .gen_fallados : vector lógico de generadores fallados (1xn). Type: logical.
%         .idx_carga    : índice del estado de carga seleccionado. Type: double.
%         .L_actual     : demanda activa del estado de carga [MW]. Type: double.
%         .Sn_SYNC      : capacidades nominales de generadores síncronos [MW]. Type: vector (1xn) double.
%   dn: período de análisis (1=día, 0=noche). Type: double.
%   pc: matriz de puntos de concentración del PEM.
%       Columnas: [punto, P_F1, P_F2, ..., P_Fm, peso]. Type: matrix (len x m+2) double.
%   len: número de puntos de concentración (0 si no hay renovables). Type: double.
%   usar_cache: habilita búsqueda y almacenamiento en caché. Type: logical.
%   cache_struct: struct con resultados previamente calculados. Type: struct.

% Retorna:
%   DNS_w: demanda no suministrada ponderada del escenario [MW]. Type: double.
%   local_cache: Map con nuevos pares clave-valor calculados en esta llamada. Type: containers.Map.
%   stats: vector [hits, misses] del caché en esta llamada. Type: vector (1x2) double.

% Inicialización del caché local y contadores de aciertos/fallos
local_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');
local_hits = 0; local_misses = 0;

% Codificación del estado de falla como número decimal (clave única)
gen_decimal = bi2de(data.gen_fallados');
key_base = sprintf('D%d_%d_%d', dn, data.idx_carga, gen_decimal);

% Potencia síncrona disponible: suma de capacidades de generadores NO fallados
SUM_Pinj_SYNC = sum(data.Sn_SYNC .* ~data.gen_fallados');

% Caso con fuentes renovables (PEM)
if len > 0
    DNS_pem = zeros(len, 1);
    for k = 1:len
        key_pem = sprintf('%s_P%d', key_base, k);
        key_safe = ['k_' strrep(key_pem, '-', '_')];
        
        if usar_cache && isfield(cache_struct, key_safe)
            DNS_pem(k) = cache_struct.(key_safe);
            local_hits = local_hits + 1;
        else
            local_misses = local_misses + 1;
            P_FERNC_k = sum(pc(k, 2:(end-1)));
            DNS_pem(k) = max(0, data.L_actual - SUM_Pinj_SYNC - P_FERNC_k);
            if usar_cache, local_cache(key_pem) = DNS_pem(k); end
        end
    end

    % DNS ponderada: promedio ponderado por los pesos del PEM
    DNS_w = sum(DNS_pem .* pc(:, end));

else % Caso sin renovables (100% síncrono)

    key_safe = ['k_' strrep(key_base, '-', '_')];
    if usar_cache && isfield(cache_struct, key_safe)
        DNS_w = cache_struct.(key_safe);
        local_hits = local_hits + 1;
    else
        local_misses = local_misses + 1;

        % DNS = déficit entre demanda y generación síncrona disponible
        DNS_w = max(0, data.L_actual - SUM_Pinj_SYNC);
        
        if usar_cache, local_cache(key_base) = DNS_w; end
    end
end

% Estadísticas de caché: [aciertos, fallos]
stats = [local_hits, local_misses];

end