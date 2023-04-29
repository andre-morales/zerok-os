# 🧊 ZeroK OS 🧊

Esse projeto é uma evolução do meu antigo XtX, desenvolvido entre 2020 e 2022, agora mais documentado.
ZeroK se trata de um sistema operacional experimental que tem como objetivo desenvolver conhecimento sobre
linguagens de baixo nível (Assembly, C e C++), arquitetura de SOs, funcionamento da CPU, e outras áreas variadas.

## Projetos Auxiliares
Durante o desenvolvimento do ZeroK, surgiu a necessidade de outros projetos complementares, como o CASM e o XtBootMgr, fundamentais no processo de criação.

## CASM
Como uma parte significante do desenvolvimento do SO e do Bootloader precisa ser feita em Assembly e essa linguagem pode ser
muito difícil de visualizar, viu-se a necessidade de criar uma linguagem auxiliar que seja transpilada para Assembly.
O CASM é quase idêntico ao Assembly, porém com algums recursos extras para melhorar o código estéticamente e funcionalmente. O transpilador foi desenvolvido em Java e encontra-se na pasta na pasta CASM no repositório.

O CASM é utilizado tanto no XtBootMgr quanto no ZeroK.

## XtBootMgr
Como parte do aprendizado fundamental do processo de boot, esse projeto também desenvolve um bootloader dedicado, flexível e minimalista.

## ✅ Metas Já Cumpridas
* Bootloader funcional para qualquer SO, instalado em qualquer partição
* Sistema agora instalável em qualquer mídia, suportando até dual-boot
* Ativação do modo 32 bits do processador
* Executar um programa compilado em C guardado no disco de boot

## 🚀 Compilação e Teste
Para compilar e testar o sistema e seus projetos auxiliares serão exigidas diversas ferramentas.
* Java para o uso do CASM
* NASM para compilar o código gerado em Assembly
* GCC para compilar o código em C.

Para testar o sistema, podem ser utilizados vários programas.
* VMWare como VirtualBox servem para executar uma imagem de disco com o sistema instalado e visualizar seu funcionamento
* PCem ou 86Box ajudam a testar o sistema com os mais diferentes tipos de hardware
* Bochs é capaz de debuggar o sistema instrução por instrução