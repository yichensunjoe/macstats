<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · [繁體中文](README_zh-TW.md) · [日本語](README_ja.md) · [한국어](README_ko.md) · [Deutsch](README_de.md) · **Español** · [Français](README_fr.md) · [Русский](README_ru.md) · [Português (Brasil)](README_pt-BR.md)

# MacS

### El Monitor de Actividad, fijado en tu escritorio.

**CPU, memoria, GPU, energía, disco y red de un vistazo, con cada cifra ajustada al Monitor de Actividad.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#instalación)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#cómo-funciona)
[![tests](https://img.shields.io/badge/tests-103%20passing-3fb950?style=flat-square)](#comandos)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#cómo-funciona)

[Instalación](#instalación) · [Qué muestra](#qué-muestra) · [Dos superficies](#dos-superficies) · [Exactitud](#cuánto-se-acerca-al-monitor-de-actividad) · [FAQ](#faq) · [Limitaciones](#limitaciones-conocidas)

**[Descargar MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · arrástralo a `/Applications` y ábrelo una vez con clic derecho → «Abrir»

</div>

---

## Instalación

[**Descargar MacStats.zip**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip) (unos 2,4 MB, macOS 15+ en Apple Silicon)

1. Descomprime y arrastra `MacStats.app` a `/Applications`
2. Haz clic derecho en MacStats → «Abrir» y confirma una vez (**sin notarizar**; el motivo y la alternativa por terminal están en las [notas de instalación](../install.md))
3. El panel aparece en el escritorio. Para el widget de WidgetKit: clic derecho en el escritorio → «Editar widgets» → busca «系统监视» (el nombre del widget en la galería)

```bash
# Opcional: quita una vez el atributo de cuarentena y después bastará con doble clic
xattr -dr com.apple.quarantine /Applications/MacStats.app

# O usa Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+ exige confiar explícitamente en taps de terceros
brew install --cask macstats
```

Verifica la descarga con `shasum -a 256 -c MacStats.zip.sha256` (la suma de comprobación está adjunta al release).

<p align="center">
  <img src="../live-window.png" alt="Panel de MacStats: CPU, memoria, GPU, energía, disco, red y los tres procesos que más memoria usan" width="460" />
</p>

El Monitor de Actividad ya lo muestra todo. El problema es que es una ventana: hay que abrirla, elegir una pestaña y traerla al frente. MacStats convierte esas mismas seis métricas en un panel oscuro que vive en el escritorio, muestrea cada segundo, reordena su diseño al cambiar de tamaño y además incluye un widget de WidgetKit para quien prefiera poner uno pequeño en la rejilla del escritorio.

No pretende ser un panel más grande. Las métricas son las cinco del Monitor de Actividad más el uso de GPU y la memoria unificada, además de una curva de 90 segundos, la carga por núcleo, el desglose de memoria y los tres procesos que más memoria consumen. El trabajo interesante no es dibujar: es **hacer que cada cifra salga idéntica a la del Monitor de Actividad**. Comparados lado a lado en el mismo instante, la memoria queda dentro de 0,2 GB y los contadores acumulados de disco y red coinciden byte a byte.

<p align="center">
  <img src="../compact-strip.png" alt="Tira ancha: CPU, memoria, GPU, energía, disco y red en una sola fila" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="Tira estrecha: las mismas seis métricas se pliegan en una cuadrícula de 3 × 2" width="330" />
</p>

**Si arrastras el panel hasta convertirlo en una tira, aparece el diseño mínimo.** Sin tarjetas ni curvas: seis métricas en una fila, como un indicador bajo la barra de menús. Cuando el panel es demasiado estrecho para una fila, se pliega en una cuadrícula de 3 × 2 y las seis siguen visibles. Con refresco de un segundo la app consume alrededor del 1 % de un núcleo y unos 80 MB residentes (medido en arm64, macOS 26), y es el nivel que menos dibuja. Es la forma predeterminada en una instalación nueva; clic derecho → «Expandir a panel estándar» abre el panel completo, y el mismo elemento vuelve a plegarlo.

> [!NOTE]
> El panel flotante funciona sin configuración. La copia de la galería de widgets del sistema necesita una firma de Apple Development válida y debe estar instalada en `/Applications`; ambas son exigencias de `chronod`, no preferencias. Ver [Extensión de widget](#extensión-de-widget).

## Compilar desde el código fuente

Requiere macOS 15 o posterior y las herramientas de línea de comandos de Xcode (Swift 6). Sin dependencias de terceros ni proyecto de Xcode.

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # compila + empaqueta + instala en /Applications + registra el widget
open /Applications/MacStats.app
```

Al abrirlo por primera vez aparece una pequeña lectura `CPU · Memoria` en la barra de menús y el panel en el escritorio.

- Clic izquierdo en el icono de la barra de menús: muestra u oculta el panel
- Clic derecho en el panel: siempre encima, fijar al escritorio, atravesar clics, intervalo de refresco (1 / 2 / 5 s), nueva instancia
- Arrastra una zona vacía para moverlo y usa el tirador inferior derecho para cambiar el tamaño; el diseño alterna entre Mínimo / Compacto / Estándar / Detallado
- Las preferencias se guardan en el dominio `com.macstats.app` de la app, así que la posición y el tamaño sobreviven a un reinicio

## Qué muestra

| Métrica | En el panel | Cómo se mide |
|---|---|---|
| CPU | Cifra total grande + usuario/sistema + curva de 90 s + barras por núcleo | Diferencias de `host_processor_info`, misma fuente que el Monitor de Actividad |
| Memoria | Usada / total, barra de presión, desglose App / Wired / comprimida, caché | `vm_statistics64`, ver [Exactitud](#cuánto-se-acerca-al-monitor-de-actividad) |
| Energía | Vatios derivados del contador de energía de la CPU, nivel y estado de la batería | Diferencias de `ri_energy_nj`; si falta el contador se usa una estimación por carga y se indica |
| Disco | Velocidad de lectura/escritura, espacio libre | Diferencias de bytes acumulados de `IOBlockStorageDriver` |
| Red | Velocidad de subida/bajada, interfaz principal | Contadores de 64 bits de `NET_RT_IFLIST2`; las velocidades excluyen `lo0` |
| GPU | Gran cifra de uso + curva de 90 s + memoria unificada usada / número de núcleos | `PerformanceStatistics` de `IOAccelerator` (`Device Utilization %`, `In use system memory`), la misma fuente que la pestaña GPU del Monitor de Actividad |
| Procesos | Los 3 que más memoria usan (5 en el widget grande) | `ri_phys_footprint` de `proc_pid_rusage` |

<p align="center">
  <img src="../widget-medium.png" alt="Widget mediano: CPU con barras por núcleo y tarjetas de memoria, disco, red, energía y GPU cuando está disponible" width="620" />
  <img src="../widget-small.png" alt="Widget pequeño: cifra grande de CPU con curva" width="280" />
</p>

## Dos superficies

Una capa de muestreo, dos anfitriones:

| | Panel de escritorio | Widget del sistema (WidgetKit) |
|---|---|---|
| Refresco | Redibuja cada segundo | Programado por el sistema, aproximadamente una vez por minuto |
| Posición | Se arrastra a cualquier sitio, varias instancias | Rejilla del escritorio, sigue al sistema |
| Entrada | Icono de la barra de menús / `open MacStats.app` | Clic derecho en el escritorio → «Editar widgets» → buscar «MacStats» |
| Tamaño | Redimensionable, cuatro niveles de diseño | Pequeño / mediano / grande / extra grande |
| Requisitos | Ninguno | Firma válida + instalación en `/Applications` + punto de entrada `_NSExtensionMain` |

Si quieres algo que se mueva, usa el panel; si quieres que encaje con tus otros widgets, el widget del sistema. Ambos leen la misma instantánea, así que no pueden contradecirse.

## Cuánto se acerca al Monitor de Actividad

El método: poner el Monitor de Actividad y el panel en la misma pantalla, leer los valores del Monitor mediante la API de accesibilidad y compararlos con una muestra tomada en el mismo instante.

| Punto | Resultado |
|---|---|
| Memoria: usada / caché / App / Wired / comprimida | Dentro de 0,2 GB (el propio Monitor conserva su vista 5 segundos) |
| Disco: leído / escrito acumulado | Idéntico byte a byte |
| Red: recibido / enviado acumulado | Idéntico byte a byte (GB decimales) |
| Memoria de procesos | 0,0 MB para el mismo PID |
| CPU | 1–3 puntos porcentuales con carga estable (desfase de la ventana de muestreo) |

<p align="center">
  <img src="../monitor-compare.png" alt="Arriba: pestaña de memoria del Monitor de Actividad. Abajo: el panel de MacStats en el mismo instante" width="700" />
</p>

Llegar ahí exigió corregir tres suposiciones:

- **El tráfico de red acumulado tiene que venir de los contadores IFMIB de 64 bits.** `ifi_ibytes` en `NET_RT_IFLIST2` solo rellena los 32 bits bajos; tras el desbordamiento, los 122,9 GB de `lo0` de este equipo se leían como 2,6 GB. Los totales incluyen `lo0` (el Monitor también lo cuenta) y las columnas de velocidad lo excluyen; de lo contrario el tráfico de bucle multiplica la velocidad por sesenta.
- **«Usada» no es «App + Wired + comprimida».** La memoria usada del Monitor es física − (libre − especulativa) − caché de archivos, y los archivos en caché son caché de archivos + páginas purgables. Hay que implementar su definición, no la intuitiva.
- **Energía no es «Impacto energético».** Esa columna es una puntuación relativa adimensional e irreproducible. El panel informa vatios físicos y etiqueta la tarjeta «contador de energía de CPU» en lugar de mezclar unidades.

## Cómo funciona

Tres capas, ninguna dependiente de la interfaz:

```
MacStatsCore  muestreo y conversiones (lógica pura, con pruebas unitarias)
      ↓
WidgetData    instantánea + historial circular de 90 puntos
      ↓
Vistas SwiftUI compartidas por el panel y la extensión de WidgetKit
```

- **Muestreo**: Mach (`host_processor_info`, `host_statistics64`), IOKit (estadísticas de disco, fuentes de energía), `sysctl(NET_RT_IFLIST2)`, `sysctl(vm.swapusage)`, libproc (`proc_listpids` / `proc_pid_rusage`). Solo API públicas: sin sudo, sin tocar SIP, sin frameworks privados.
- **Las métricas de velocidad son la media móvil de las últimas cinco muestras**, igualando la ventana de 5 segundos del Monitor y suavizando el parpadeo.
- **El panel es un `NSPanel` de nivel de escritorio**: no se activa, acompaña a todos los Spaces y nunca toma el foco, así que hacer clic no manda tu ventana actual al fondo.
- **Los datos no salen del equipo**: sin peticiones de red, sin telemetría, sin cuentas y sin leer archivos del usuario. Solo lee contadores del sistema por API públicas y escribe un JSON local para la extensión.

## Comandos

| Objetivo | Comando |
|---|---|
| Compilar, empaquetar, instalar | `bash scripts/bundle.sh` |
| Pruebas unitarias | `cd src && swift test` |
| Autocomprobación del muestreo | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| Mostrar contadores en bruto | `cd src && .build/debug/macstatsDiag --raw` |
| Instantánea JSON | `cd src && .build/debug/macstatsDiag --json` |
| Renderizar el panel fuera de pantalla | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| Renderizar los cuatro tamaños de widget | `bash scripts/preview-widget.sh` |

## Estructura del proyecto

```
src/Sources/MacStatsCore/    muestreo, cálculo de memoria, historial circular, formato (sin UI)
src/Sources/MacStats/        panel SwiftUI, app de barra de menús, menú contextual, render fuera de pantalla
src/Sources/MacStatsWidget/  extensión WidgetKit: proveedor de líneas de tiempo + cuatro vistas
src/Sources/MacStatsDiag/    CLI de diagnóstico (--json / --raw / --self-check)
src/Tests/                   XCTest, 103 casos
scripts/bundle.sh            compilación release, ensamblado del appex, firma, instalación, registro
docs/                        notas de cotejo, arquitectura, requisitos, capturas
```

## Extensión de widget

La extensión se empaqueta en `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`, con un diseño por tamaño. Para que aparezca en la galería hacen falta tres cosas, todas descubiertas a base de golpes:

1. **La extensión necesita una firma válida y estar en sandbox.** `pkd` rechaza firmas ad-hoc, y aun con un certificado real un appex sin `com.apple.security.app-sandbox` se descarta en silencio con `rejecting; … plug-ins must be sandboxed`. Basta un certificado gratuito de equipo personal (Xcode → Settings → Accounts → iniciar sesión con un Apple ID).
2. **La app debe estar en `/Applications` y solo puede haber una copia registrada.** `chronod` descubre anfitriones únicamente en la carpeta de aplicaciones del sistema; desde el directorio del proyecto o una carpeta Applications de usuario el registro dice `Ignoring restricted or unknown extension`. Dos registros del mismo bundle id hacen que launchd cree dos instancias XPC y `chronod` ya no alcanza el proceso real. `bundle.sh` instala y limpia registros antiguos en consecuencia.
3. **El punto de entrada del appex debe ser `_NSExtensionMain`.** Es el `LD_ENTRY_POINT` por defecto de Xcode; con el de SwiftPM el proceso arranca, imprime `main [WidgetBundle]`, nunca establece la sesión XPC con el anfitrión y se lo declara muerto unos 15 ms después, sin informe de fallo. `src/Package.swift` lo fija con `linkerSettings`.

Una extensión en sandbox no puede leer los `UserDefaults` de la app anfitriona, así que los datos viajan como instantánea JSON: la app la reescribe cada 2 segundos en su carpeta de Application Support y la replica en el contenedor de la extensión cuando existe; si la extensión no encuentra una instantánea reciente, muestrea una vez por su cuenta.

Si `security find-identity -v -p codesigning` informa `0 valid identities`, normalmente falta el certificado intermedio WWDR G3 de Apple: importa `AppleWWDRCA-2030.cer` desde los recursos de Xcode.

Tras cambiar la extensión, sube `CFBundleVersion`: `chronod` cachea los descriptores por versión y seguirá mostrando el antiguo.

## FAQ

<details>
<summary><strong>¿Por qué el widget solo se actualiza una vez por minuto?</strong></summary>

WidgetKit no es un bucle de render, es una instantánea programada: la línea de tiempo entrega una entrada y el sistema pide la siguiente al caducar. Aunque la app solicite `reloadAllTimelines()` cada 15 segundos, `chronod` aplica un presupuesto (el registro dice `budgeted-1`). Los widgets de terceros no pueden refrescar cada segundo; el reloj del sistema es un privilegio del sistema, no de las extensiones.

Para cifras en vivo, usa el panel de escritorio, que redibuja cada segundo.

</details>

<details>
<summary><strong>¿Por qué no aparece WindowServer entre los procesos con más memoria?</strong></summary>

Los procesos de otros usuarios (como `_windowserver`) no son legibles: `proc_pid_rusage` devuelve EPERM y `proc_pidinfo` devuelve cero bytes. El Monitor de Actividad lleva un entitlement de Apple que le permite verlo todo. Es un límite de permisos, no un error de cálculo.

</details>

<details>
<summary><strong>Alguna cifra sigue difiriendo un poco.</strong></summary>

El Monitor de Actividad se refresca cada 5 segundos y muestra la instantánea del refresco anterior; el panel, cada segundo. Comparado en el mismo instante, la memoria puede diferir hasta 0,2 GB y las velocidades y la CPU difieren por el desfase de la ventana. Vuelve a comparar tras un ciclo y coincidirán.

</details>

<details>
<summary><strong>¿Sube datos a algún sitio?</strong></summary>

No. Sin peticiones de red, sin telemetría, sin cuentas y sin leer archivos del usuario. Lee contadores del sistema por API públicas y escribe un JSON local para la extensión del widget.

</details>

<details>
<summary><strong>¿Funciona en Macs Intel?</strong></summary>

El código solo usa API públicas y debería ser portable, pero solo se ha probado en arm64 (macOS 26). Las conversiones de CPU y energía no tienen datos de calibración para Intel. Los issues con tus propias comparaciones son bienvenidos.

</details>

## Limitaciones conocidas

- **El widget del sistema avanza más o menos cada 60 segundos.** Es el límite de planificación de WidgetKit; ninguna app puede evitarlo.
- **La energía son vatios físicos**, no la puntuación «Impacto energético» del Monitor. No hay correspondencia de unidades.
- **La lista de procesos cubre solo al usuario actual**, ordenada por memoria: el panel muestra tres y la capa de muestreo guarda hasta 24.
- **El historial es local y llega al minuto**: se agrega por minuto y se escribe como JSONL, con retención de 7 / 30 / 90 días. Sin sincronización en la nube ni reproducción por segundos.
- **Las alertas solo cubren tres valores**: CPU / memoria / disco, tras tres muestras consecutivas por encima del umbral y desactivadas por defecto. No vigilan temperatura, ventiladores ni un proceso concreto.
- **Sin monitorización remota**: todas las lecturas y el historial se quedan en este Mac y no salen a la red.

## Documentación

Las notas detalladas están en chino.

- [Notas de cotejo](../monitor-alignment.md): cómo se ajusta cada valor al Monitor de Actividad, con mediciones.
- [Arquitectura](../architecture.md): capas, flujo de datos y sus compromisos.
- [Requisitos](../requirements.md): alcance, no objetivos y criterios de aceptación.

## Licencia

Publicado bajo la [licencia MIT](../../LICENSE). Puedes usarlo, modificarlo y distribuirlo, incluso con fines comerciales, siempre que conserves el aviso de copyright y el texto de la licencia.
