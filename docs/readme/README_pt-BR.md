<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · [繁體中文](README_zh-TW.md) · [日本語](README_ja.md) · [한국어](README_ko.md) · [Deutsch](README_de.md) · [Español](README_es.md) · [Français](README_fr.md) · [Русский](README_ru.md) · **Português (Brasil)**

# MacStats Panel

### O Monitor de Atividade, fixado na sua mesa.

**CPU, memória, GPU, energia, disco e rede em um relance, com cada número alinhado ao Monitor de Atividade.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#instalação)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#como-funciona)
[![tests](https://img.shields.io/badge/tests-176%20passing-3fb950?style=flat-square)](#comandos)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#como-funciona)

[Instalação](#instalação) · [O que mostra](#o-que-mostra) · [Duas superfícies](#duas-superfícies) · [Precisão](#quão-perto-fica-do-monitor-de-atividade) · [FAQ](#faq) · [Limitações](#limitações-conhecidas)

**[Baixar MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · arraste para `/Applications` e, na primeira abertura, libere em Ajustes do Sistema → “Abrir Mesmo Assim”

</div>

---

## Instalação

[**Baixar MacStats.zip**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip) (cerca de 2,5 MB, macOS 15+ em Apple Silicon)

1. Descompacte e arraste `MacStats.app` para `/Applications`
2. A primeira abertura é bloqueada (**sem notarização**): clique em “Concluído” no aviso e depois Ajustes do Sistema → Privacidade e Segurança → “Abrir Mesmo Assim”; ou remova o atributo de quarentena no terminal. O motivo e os dois caminhos estão nas [notas de instalação](../install.md)
3. O painel aparece na mesa. Para o widget do WidgetKit: clique com o botão direito na mesa → “Editar widgets” → procure “系统监视” (o nome do widget na galeria)

```bash
# Opcional: remova uma vez o atributo de quarentena; depois basta dar dois cliques
xattr -dr com.apple.quarantine /Applications/MacStats.app

# Ou use o Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+ exige confiar explicitamente em taps de terceiros
brew install --cask macstats
```

Verifique o download com `shasum -a 256 -c MacStats.zip.sha256` (o checksum acompanha o release).

<p align="center">
  <img src="../live-window.png" alt="Painel do MacStats: CPU, memória, GPU, energia, disco, rede e os três processos que mais consomem memória" width="460" />
</p>

O Monitor de Atividade já mostra tudo. O problema é que ele é uma janela: precisa abrir, escolher uma aba e trazer para a frente. O MacStats transforma essas mesmas seis métricas em um painel escuro que fica na mesa, amostra a cada segundo, reorganiza o layout ao redimensionar e ainda traz um widget do WidgetKit para quem prefere colocar um pequeno na grade da mesa.

Ele não tenta ser um painel maior. As métricas são as cinco do Monitor de Atividade mais o uso de GPU e a memória unificada, além de uma curva de 90 segundos, a carga por núcleo, a composição da memória e os três processos que mais consomem memória. O trabalho interessante não é desenhar: é **fazer cada número sair igual ao do Monitor de Atividade**. Comparados lado a lado no mesmo instante, a memória fica dentro de 0,2 GB e os contadores acumulados de disco e rede batem byte a byte.

<p align="center">
  <img src="../compact-strip.png" alt="Faixa larga: CPU, memória, GPU, energia, disco e rede em uma linha" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="Faixa estreita: as mesmas seis métricas se dobram em uma grade 3 × 2" width="330" />
</p>

**Ao arrastar o painel até virar uma faixa, entra o layout mínimo.** Sem cartões nem curvas: seis métricas em uma linha, como um indicador abaixo da barra de menus. Quando o painel fica estreito demais para uma linha, ele se dobra em uma grade 3 × 2 e as seis continuam visíveis. Com atualização de um segundo o app consome cerca de 1% de um núcleo e uns 80 MB residentes (medido em arm64, macOS 26), e é o nível que menos desenha. É a forma padrão em uma instalação nova; clique direito → “Expandir para painel padrão” abre o painel completo, e o mesmo item volta a recolher.

> [!NOTE]
> O painel flutuante funciona sem configuração. A cópia da galeria de widgets do sistema exige uma assinatura Apple Development válida e instalação em `/Applications` — ambas são exigências do `chronod`, não preferências. Veja [Extensão de widget](#extensão-de-widget).

## Compilar a partir do código-fonte

Requer macOS 15 ou mais recente e as ferramentas de linha de comando do Xcode (Swift 6). Sem dependências de terceiros e sem projeto do Xcode.

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # compila + empacota + instala em /Applications + registra o widget
open /Applications/MacStats.app
```

Na primeira abertura aparece uma pequena leitura `CPU · Memória` na barra de menus e o painel na mesa.

- Clique esquerdo no ícone da barra de menus: mostra ou esconde o painel
- Clique direito no painel: sempre no topo, fixar na mesa, atravessar cliques, intervalo de atualização (1 / 2 / 5 s), nova instância
- Arraste uma área vazia para mover e use a alça no canto inferior direito para redimensionar; o layout alterna entre Mínimo / Compacto / Padrão / Detalhado
- As preferências ficam no domínio `com.macstats.app`, então posição e tamanho sobrevivem a um reinício

## O que mostra

| Métrica | No painel | Como é medida |
|---|---|---|
| CPU | Número grande do total + usuário/sistema + curva de 90 s + barras por núcleo | Diferenças de `host_processor_info`, mesma fonte do Monitor de Atividade |
| Memória | Usada / total, barra de pressão, composição App / Wired / comprimida, cache | `vm_statistics64`, veja [Precisão](#quão-perto-fica-do-monitor-de-atividade) |
| Energia | Watts derivados do contador de energia da CPU, nível e estado da bateria | Diferenças de `ri_energy_nj`; sem o contador, usa uma estimativa por carga e avisa |
| Disco | Velocidade de leitura/escrita, espaço livre | Diferenças de bytes acumulados do `IOBlockStorageDriver` |
| Rede | Velocidade de envio/recebimento, interface principal | Contadores de 64 bits do `NET_RT_IFLIST2`; as velocidades excluem `lo0` |
| GPU | Número grande de uso + curva de 90 s + memória unificada usada / núcleos | `PerformanceStatistics` do `IOAccelerator` (`Device Utilization %`, `In use system memory`), a mesma fonte da aba GPU do Monitor de Atividade |
| Processos | Os 3 maiores em memória (5 no widget grande) | `ri_phys_footprint` do `proc_pid_rusage` |

<p align="center">
  <img src="../widget-medium.png" alt="Widget médio: CPU com barras por núcleo e blocos de memória, disco, rede, energia e GPU quando disponível" width="620" />
  <img src="../widget-small.png" alt="Widget pequeno: número grande de CPU com curva" width="280" />
</p>

## Duas superfícies

Uma camada de amostragem, dois hospedeiros:

| | Painel da mesa | Widget do sistema (WidgetKit) |
|---|---|---|
| Atualização | Redesenha a cada segundo | Agendada pelo sistema, cerca de uma vez por minuto |
| Posição | Arrasta para qualquer lugar, várias instâncias | Grade da mesa, segue o sistema |
| Entrada | Ícone da barra de menus / `open MacStats.app` | Clique direito na mesa → "Editar Widgets" → buscar "MacStats" |
| Tamanho | Redimensionamento livre, quatro níveis | Pequeno / médio / grande / extra grande |
| Pré-requisitos | Nenhum | Assinatura válida + instalação em `/Applications` + ponto de entrada `_NSExtensionMain` |

Se quer algo que se mova, use o painel; se quer alinhar com os outros widgets, o widget do sistema. Os dois leem o mesmo instantâneo, então não têm como divergir.

## Quão perto fica do Monitor de Atividade

O método: colocar o Monitor de Atividade e o painel na mesma tela, ler os valores do Monitor pela API de acessibilidade e comparar com uma amostra tirada no mesmo instante.

| Item | Resultado |
|---|---|
| Memória: usada / cache / App / Wired / comprimida | Dentro de 0,2 GB (o próprio Monitor congela a exibição por 5 segundos) |
| Disco: total lido / gravado | Idêntico byte a byte |
| Rede: total recebido / enviado | Idêntico byte a byte (GB decimais) |
| Memória de processos | 0,0 MB para o mesmo PID |
| CPU | 1–3 pontos percentuais sob carga estável (defasagem da janela de amostragem) |

<p align="center">
  <img src="../monitor-compare.png" alt="Acima: aba de memória do Monitor de Atividade. Abaixo: o painel do MacStats no mesmo instante" width="700" />
</p>

Para chegar lá foi preciso corrigir três suposições:

- **O tráfego de rede acumulado tem que vir dos contadores IFMIB de 64 bits.** `ifi_ibytes` no `NET_RT_IFLIST2` preenche só os 32 bits baixos; depois do estouro, os 122,9 GB de `lo0` desta máquina eram lidos como 2,6 GB. Os totais incluem `lo0` (o Monitor também conta) e as colunas de velocidade o excluem — caso contrário o tráfego de loopback multiplica a velocidade por sessenta.
- **"Usada" não é "App + Wired + comprimida".** A memória usada do Monitor é física − (livre − especulativa) − cache de arquivos, e arquivos em cache são cache de arquivos + páginas purgáveis. É preciso implementar a definição dele, não a intuitiva.
- **Energia não é "Impacto energético".** Aquela coluna é uma pontuação relativa adimensional e irreproduzível. O painel mostra watts físicos e rotula o bloco como "contador de energia da CPU", sem misturar unidades.

## Como funciona

Três camadas, nenhuma dependente da interface:

```
MacStatsCore  amostragem e conversões (lógica pura, com testes unitários)
      ↓
WidgetData    instantâneo + histórico circular de 90 pontos
      ↓
Views SwiftUI compartilhadas pelo painel e pela extensão WidgetKit
```

- **Amostragem**: Mach (`host_processor_info`, `host_statistics64`), IOKit (estatísticas de disco, fontes de energia), `sysctl(NET_RT_IFLIST2)`, `sysctl(vm.swapusage)`, libproc (`proc_listpids` / `proc_pid_rusage`). Apenas APIs públicas: sem sudo, sem desativar o SIP, sem frameworks privados.
- **As métricas de velocidade são a média móvel das últimas cinco amostras**, alinhadas à janela de 5 segundos do Monitor e suavizando a trepidação.
- **O painel é um `NSPanel` de nível de mesa**: não ativante, presente em todos os Spaces, nunca rouba o foco, então clicar nele não manda sua janela atual para trás.
- **Os dados não saem da máquina**: sem requisições de rede, telemetria, contas ou leitura de arquivos do usuário. Só lê contadores do sistema por APIs públicas e grava um JSON local para a extensão.

## Comandos

| Objetivo | Comando |
|---|---|
| Compilar, empacotar, instalar | `bash scripts/bundle.sh` |
| Testes unitários | `cd src && swift test` |
| Autoteste da amostragem | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| Imprimir contadores brutos | `cd src && .build/debug/macstatsDiag --raw` |
| Instantâneo em JSON | `cd src && .build/debug/macstatsDiag --json` |
| Renderizar o painel fora da tela | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| Renderizar os quatro tamanhos de widget | `bash scripts/preview-widget.sh` |

## Estrutura do projeto

```
src/Sources/MacStatsCore/    amostragem, cálculo de memória, histórico circular, formatação (sem UI)
src/Sources/MacStats/        painel SwiftUI, app da barra de menus, menu de contexto, renderização fora da tela
src/Sources/MacStatsWidget/  extensão WidgetKit: provedor de timeline + quatro visões
src/Sources/MacStatsDiag/    CLI de diagnóstico (--json / --raw / --self-check)
src/Tests/                   XCTest, 176 casos
scripts/bundle.sh            build release, montagem do appex, assinatura, instalação, registro
docs/                        notas de comparação, arquitetura, requisitos, capturas
```

## Extensão de widget

A extensão fica em `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`, com layout próprio por tamanho. Para aparecer na galeria são necessárias três coisas, todas descobertas na prática:

1. **A extensão precisa de assinatura válida e sandbox.** O `pkd` recusa assinaturas ad-hoc, e mesmo com certificado real um appex sem `com.apple.security.app-sandbox` é descartado em silêncio com `rejecting; … plug-ins must be sandboxed`. Um certificado gratuito de equipe pessoal (Xcode → Settings → Accounts → entrar com um Apple ID) basta.
2. **O app precisa estar em `/Applications` e só uma cópia pode estar registrada.** O `chronod` descobre hospedeiros apenas na pasta de aplicativos do sistema; rodando da pasta do projeto ou de uma pasta Applications do usuário, o log mostra `Ignoring restricted or unknown extension`. Dois registros do mesmo bundle id fazem o launchd criar duas instâncias XPC e o `chronod` deixa de alcançar o processo real. O `bundle.sh` instala e limpa registros antigos seguindo essa premissa.
3. **O ponto de entrada do appex precisa ser `_NSExtensionMain`.** É o `LD_ENTRY_POINT` padrão do Xcode; com o do SwiftPM o processo inicia, imprime `main [WidgetBundle]`, nunca estabelece a sessão XPC com o hospedeiro e é declarado morto cerca de 15 ms depois, sem relatório de falha. O `src/Package.swift` fixa isso via `linkerSettings`.

Uma extensão em sandbox não consegue ler os `UserDefaults` do app hospedeiro, então os dados vão como instantâneo JSON: o app o reescreve a cada 2 segundos na pasta Application Support e replica no contêiner da extensão quando ele existe; se a extensão não encontra um instantâneo recente, ela mesma amostra uma vez.

Se `security find-identity -v -p codesigning` mostrar `0 valid identities`, normalmente falta o certificado intermediário WWDR G3 da Apple: importe `AppleWWDRCA-2030.cer` dos recursos do Xcode.

Depois de alterar a extensão, aumente o `CFBundleVersion`: o `chronod` guarda descritores em cache por versão e continuará mostrando o antigo.

## FAQ

<details>
<summary><strong>Por que o widget só atualiza cerca de uma vez por minuto?</strong></summary>

O WidgetKit não é um loop de renderização, e sim um instantâneo agendado: a timeline entrega uma entrada e o sistema pede a próxima quando ela expira. Mesmo com o app chamando `reloadAllTimelines()` a cada 15 segundos, o `chronod` aplica um orçamento (o log traz `budgeted-1`). Widgets de terceiros não podem atualizar a cada segundo; o relógio do sistema é um privilégio do sistema, não das extensões.

Para números ao vivo, use o painel da mesa, que redesenha a cada segundo.

</details>

<details>
<summary><strong>Por que o WindowServer não aparece entre os processos que mais consomem memória?</strong></summary>

Processos de outros usuários (como `_windowserver`) não são legíveis: `proc_pid_rusage` retorna EPERM e `proc_pidinfo` retorna zero bytes. O Monitor de Atividade tem um entitlement da Apple que permite ver tudo. É uma fronteira de permissão, não um erro de cálculo.

</details>

<details>
<summary><strong>Algum número ainda difere um pouco.</strong></summary>

O Monitor de Atividade atualiza a cada 5 segundos e mostra o instantâneo da atualização anterior; o painel, a cada segundo. Comparando no mesmo instante, a memória pode diferir até 0,2 GB e as velocidades e a CPU diferem pela defasagem da janela. Compare de novo após um ciclo e eles coincidem.

</details>

<details>
<summary><strong>Ele envia dados para algum lugar?</strong></summary>

Não. Sem requisições de rede, telemetria, contas ou leitura de arquivos do usuário. Só lê contadores do sistema por APIs públicas e grava um JSON local para a extensão do widget.

</details>

<details>
<summary><strong>Funciona em Macs Intel?</strong></summary>

O código só usa APIs públicas e deve ser portável, mas foi testado apenas em arm64 (macOS 26). As conversões de CPU e energia não têm dados de calibração para Intel. Issues com suas próprias comparações são bem-vindas.

</details>

## Limitações conhecidas

- **O widget do sistema avança cerca de 60 em 60 segundos.** É o limite de agendamento do WidgetKit; nenhum app consegue contornar.
- **Energia são watts físicos**, não a pontuação "Impacto energético" do Monitor. Não há correspondência de unidades.
- **A lista de processos cobre só o usuário atual**, ordenada por memória: o painel mostra três e a camada de amostragem guarda até 24.
- **O histórico é local e chega ao minuto**: agregado por minuto e gravado em JSONL, com retenção de 7 / 30 / 90 dias. Sem sincronização na nuvem nem reprodução por segundo.
- **Os alertas cobrem só três valores**: CPU / memória / disco, após três amostras consecutivas acima do limite, desligados por padrão. Não monitoram temperatura, ventoinhas nem um processo isolado.
- **Sem monitoramento remoto**: todas as leituras e o histórico ficam neste Mac e não vão para a rede.

## Documentação

As notas detalhadas estão em chinês.

- [Notas de comparação](../monitor-alignment.md): como cada valor foi alinhado ao Monitor de Atividade, com medições.
- [Arquitetura](../architecture.md): camadas, fluxo de dados e as escolhas por trás delas.
- [Requisitos](../requirements.md): escopo, não objetivos e critérios de aceitação.

## Licença

Publicado sob a [licença MIT](../../LICENSE). Você pode usar, modificar e distribuir, inclusive comercialmente, desde que mantenha o aviso de copyright e o texto da licença.
