<h1 align="center">Proyecto 1 – Confiabilidad en Sistemas de Potencia (2026)</h1>

<p align="center">
<img src="https://img.shields.io/badge/STATUS-FRAMEWORK-blue">
<img src="https://img.shields.io/badge/MATLAB-R2022%2B-orange">
<img src="https://img.shields.io/badge/NIVEL-HL--I-blue">
</p>

---

# 📑 Índice

- [Información general](#info-general)
- [Objetivo del proyecto](#objetivo)
- [Arquitectura del framework](#arquitectura)
- [Metodología implementada](#metodologia)
- [Entorno de desarrollo](#entorno)
- [Uso del framework](#uso)
- [Índices de confiabilidad](#indices)
- [Parámetros configurables](#parametros)
- [Importante](#importante)
- [Estructura del repositorio](#estructura)
- [Archivos proporcionados](#archivos)
- [Autora](#autora)

---

<a id="info-general"></a>
## 💡 Información general

<p align="justify">
Este repositorio contiene el framework base y los casos de estudio para el desarrollo del Proyecto 1 del curso:
</p>

<p align="justify">
<strong>Curso:</strong> Confiabilidad en Sistemas de Potencia (2026).<br>
<strong>Profesor:</strong> Dr. Mario Alberto Ríos Mesías, Ph.D.<br>
<strong>Universidad:</strong> Universidad de los Andes.
</p>

---

<a id="objetivo"></a>
## 🎯 Objetivo del proyecto

<p align="justify">
Evaluar la confiabilidad del sistema de generación del IEEE RTS-24 mediante simulación de Monte Carlo (Nivel
Jerárquico I), analizando:
</p>

<p align="justify">
1. El impacto del nivel de demanda sobre los índices de confiabilidad.<br>
2. El efecto de reemplazar generación síncrona por fuentes renovables (eólica y solar).<br>
3. La capacidad equivalente de fuentes renovables por igualación de E[DNS] a carga fija.<br>
</p>

---

<a id="arquitectura"></a>
## 🏗 Arquitectura del framework

<p align="justify">
El framework sigue una arquitectura modular compuesta por:
</p>

<p align="justify">
1. <strong>Capa de datos</strong>: carga del sistema IEEE RTS-24 y perfiles renovables.<br>
2. <strong>Capa probabilística</strong>: modelado de fallas de generación y variables FNCER.<br>
3. <strong>Motor Monte Carlo</strong>: simulación no secuencial en HL-I.<br>
4. <strong>Integración PEM (2m+1)</strong>: tratamiento probabilístico de renovables.<br>
5. <strong>Capa estadística</strong>: estimación de índices de confiabilidad.<br>
6. <strong>Capa de ejecución</strong>: scripts que configuran escenarios.
</p>

---

<a id="metodologia"></a>
## 👩‍💻 Metodología implementada

<p align="justify">
- Simulación Monte Carlo no secuencial (HL-I).<br>
- Truncamiento del espacio de estados (ej. K ≤ 2).<br>
- Integración FNCER mediante Point Estimate Method (PEM – 2m+1).<br>
- Estimación estadística con control de error relativo.
</p>

---

<a id="entorno"></a>
## 🖥 Entorno de desarrollo

<p align="justify">
Desarrollado en:
</p>

<p align="justify">
- <strong>MATLAB</strong> (compatible R2022+).<br>
- Ejecución paralela opcional mediante <code>parpool</code>.<br>
- Módulos críticos protegidos como <strong>P-code (.p)</strong>.<br>
- No requiere toolboxes especializados adicionales.
</p>

---

<a id="uso"></a>
## ▶ Uso del framework

<p align="justify">
1. Descargar o clonar el repositorio.<br>
2. Abrir MATLAB.<br>
3. Ejecutar uno de los scripts ubicados en la carpeta <code>SCRIPTS</code>.
</p>

---

<a id="indices"></a>
## 📊 Índices de confiabilidad

| Índice | Definición | Unidad |
|--------|------------|--------|
| E[DNS] | Valor esperado de la demanda no suministrada | MW |
| LOLP | Probabilidad de pérdida de carga | - |
| LOLE | Expectativa de pérdida de carga = LOLP × h_periodo | horas/año |
| LOEE | Expectativa de pérdida de energía = E[DNS] × h_periodo | MWh/año |

---

<a id="parametros"></a>
## ⚙ Parámetros configurables

| Parámetro | Descripción | Valores |
|------------|------------|----------|
| p_max | Demanda pico del sistema [MW] | 2850 a 3400 |
| dn | Período del día | 1 = día, 0 = noche |
| factor_cap | Multiplicador capacidad renovable | 1, 2, 3, ... |
| VA | Tipo de variables FNCER | 0 = correlacionadas, 1 = independientes |
| r | Realizaciones objetivo | 10,000 a 500,000 |
| eps | Error relativo máximo | 0.03 a 0.10 |
| graficar | Graficar convergencia | true / false |

---

<a id="importante"></a>
## ⚠ Importante

<p align="justify">
Este repositorio <strong>NO incluye la solución del taller</strong>.
</p>

---

<a id="estructura"></a>
## 📂 Estructura del repositorio

### DATA/
- `Carga.xlsx`
- `Solar.csv`

### FUNCIONES/
- `SMC_Nivel1.p`
- `PEM.p`
- `Generacion_eolica.m`
- `Generacion_solar.m`
- `calcular_dns_escenario.m`
- `Histograma_carga.m`
- `bi2de.m`

### SCRIPTS/
- `script_base.m`
- `script_eolica.m`
- `script_solar.m`

---

<a id="archivos"></a>
## 📁 Archivos proporcionados

### Scripts principales

| Archivo | Descripción |
|----------|------------|
| `script_base.m` | Caso base con generación 100% síncrona |
| `script_eolica.m` | Escenario con integración eólica |
| `script_solar.m` | Escenario con integración solar |

### Funciones del framework

| Archivo | Descripción |
|----------|------------|
| `SMC_Nivel1.p` | Motor principal de simulación Monte Carlo HL-I |
| `Generacion_eolica.m` | Modelado estadístico de generación eólica |
| `Generacion_solar.m` | Modelado estadístico de generación solar |
| `PEM.p` | Implementación del método Point Estimate Method (2m+1) |
| `Histograma_carga.m` | Construcción del modelo probabilístico de demanda |
| `calcular_dns_escenario.m` | Cálculo del DNS ponderado por escenario |
| `bi2de.m` | Conversión vector binario → decimal |

### Archivos de datos

| Archivo | Descripción |
|----------|------------|
| `Carga.xlsx` | Datos de la curva de carga del sistema |
| `Solar.csv` | Perfil estadístico de generación solar |

---

<a id="autora"></a>
## ✍ Autora

María Daniela Medina Buitrago  
2026
