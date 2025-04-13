# GraphTextGen

# Proyecto: Interpolación Bilineal y Selección de Cuadrantes

Este proyecto implementa un sistema para realizar interpolación bilineal en imágenes a partir de cuadrantes seleccionados por el usuario. Los resultados se guardan como imágenes en formato `.png` para su visualización.

## Herramientas Utilizadas

### 1. **Python**
- **Bibliotecas**: 
  - `numpy`: Para manipulación de matrices de píxeles.
  - `Pillow (PIL)`: Para trabajar con imágenes y convertirlas a formato `.png` o `.jpg` .
  - `matplotlib`: Para visualizar los resultados y generar gráficos.
  - `subprocess`: Para ejecutar el programa ensamblador directamente desde Python.
  
### 2. **NASM (Netwide Assembler)**
- Ensamblador utilizado para implementar la interpolación bilineal en lenguaje ensamblador x86-64.

### 3. **GCC/LD (GNU Linker)**
- Herramienta utilizada para enlazar el código ensamblador y generar el ejecutable.

---

## Estructura del Proyecto

```
Proyecto
├── bilinear_framework.py     # Framework en Python para gestionar todo el flujo del proceso
├── bilinear_interpolation.asm # Código ensamblador para la interpolación bilineal
├── convert_to_png.py         # Script de conversión de archivos .img a PNG
├── input_image.jpg           # Imagen de entrada (ejemplo)
├── input_quadrant.img        # Archivo temporal para el cuadrante seleccionado
├── result.img                # Archivo generado por el ensamblador con la imagen interpolada
├── converted_image.png       # Resultado final en formato PNG
└── README.md                 # Instrucciones y documentación del proyecto
```

---

## Instrucciones de Uso

### Requisitos Previos

1. **Python 3.8+** con las bibliotecas necesarias instaladas:
   ```bash
   pip install numpy pillow matplotlib
   ```
2. **NASM** instalado para compilar el código ensamblador:
   ```bash
   sudo apt install nasm
   ```
3. **GCC/LD** (GNU Linker) para enlazar el ensamblador:
   ```bash
   sudo apt install build-essential
   ```

---

### Pasos para Ejecutar el Proyecto

#### 1. Seleccionar el cuadrante y procesar la imagen
Ejecuta el framework principal en Python:

```bash
python3 main.py
```

Sigue las instrucciones en la terminal:
1. Ingresa la ruta de la imagen de entrada (por defecto: `input_image.jpg`).
2. Selecciona el número del cuadrante (1-16).
3. El programa:
   - Divide la imagen en cuadrantes.
   - Genera un archivo `.img` para el cuadrante seleccionado.
   - Ejecuta el programa ensamblador para aplicar interpolación bilineal.
   - Convierte el resultado final a `.png`.

#### 2. Verificar los resultados
El programa generará:
- **Cuadrante Seleccionado (`input_quadrant.img`)**: Imagen cruda del cuadrante seleccionado.
- **Resultado Interpolado (`converted_image.png`)**: Imagen resultante después de la interpolación bilineal.
- **Gráfico Comparativo (`bilinear_results.png`)**: Visualización de la imagen original, el cuadrante seleccionado y el resultado interpolado.

---

### Manual de Uso Avanzado

#### Compilación Manual del Código Ensamblador
En caso de que necesites compilar el ensamblador manualmente:
1. Compila el archivo `.asm`:
   ```bash
   nasm -f elf64 bilinear_interpolation.asm -o bilinear_interpolation.o
   ```
2. Enlaza el archivo objeto:
   ```bash
   ld bilinear_interpolation.o -o bilinear_interpolation
   ```
3. Ejecuta el programa:
   ```bash
   ./bilinear_interpolation
   ```

#### Conversión a PNG Manual
Si se necesita convertir un archivo `.img` generado por el ensamblador:
```bash
python3 convert_to_png.py
```

---

## Notas Técnicas

- El archivo ensamblador genera un archivo `.img` con un encabezado de 12 bytes que contiene:
  - **Ancho** (4 bytes, entero).
  - **Alto** (4 bytes, entero).
  - **Número de canales** (4 bytes, entero).
- El formato `.img` es un archivo binario crudo con los datos de píxeles en escala de grises.

---

## Ejemplo de Ejecución

1. Imagen Original:
   - Ruta: `input_image.jpg`
   - Dimensiones: 720x720 píxeles.

2. Selección del Cuadrante:
   - Cuadrante #6 seleccionado (fila 2, columna 2).
   - Dimensiones del cuadrante: 180x170 píxeles.

3. Resultado Interpolado:
   - Dimensiones: 360x340 píxeles.
   - Guardado como: `converted_image.png`.

4. Visualización:
   - Gráfico comparativo guardado como: `bilinear_results.png`.

---
