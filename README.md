# 🧊 ZeroK OS 🧊

Esse projeto é uma evolução do meu antigo XtX, desenvolvido entre 2020 e 2022, agora mais documentado.
ZeroK se trata de um sistema operacional experimental que tem como objetivo desenvolver conhecimento sobre
linguagens de baixo nível (Assembly, C e C++), arquitetura de SOs, funcionamento da CPU, entre outras áreas.

## Projetos Auxiliares
Durante o desenvolvimento do ZeroK, surgiu a necessidade de outros projetos tangentes complementares, como é o caso do Pasme e o XtBootMgr.

## Pasme
Antigo CASM, criado para simplificar o processo do desenvolvimento do SO e do Bootloader.
A linguagem é desenvolvida conforme a necessidade do projeto e é quase idêntica a linguagem Assembly, porém com alguns recursos extras para melhorar o código estéticamente e funcionalmente.
A ferramenta Pasme é desenvolvida em Java e contém o transpilador e alguns outros recursos úteis. Seu código fonte se encontra na pasta Tools/Pasme do repositório.
O Pasme é utilizado tanto no XtBootMgr quanto no ZeroK.

Para fins legados, o CASM continua no repositório na pasta Tools/CASM 1, porém ele não deve ser usado no futuro.

## XtBootMgr
Como parte do aprendizado fundamental do processo de boot, esse projeto também desenvolve um bootloader dedicado, flexível e minimalista.

## ✅ Metas Já Cumpridas
* Bootloader funcional para qualquer SO, instalado em qualquer partição
* Sistema agora instalável em qualquer mídia, suportando até dual-boot
* Ativação do modo 32 bits do processador
* Executar um programa compilado em C guardado no disco de boot

## 🚀 Compilação e Teste
Para compilar e testar o sistema e seus projetos auxiliares serão exigidas diversas ferramentas.
* Java para o uso do Pasme
* NASM para compilar o código gerado em Assembly
* GCC para compilar o código em C.

Para testar o sistema, podem ser utilizados vários programas.
* VMWare como VirtualBox servem para executar uma imagem de disco com o sistema instalado e visualizar seu funcionamento
* PCem ou 86Box ajudam a testar o sistema com os mais diferentes tipos de hardware
* Bochs é capaz de debuggar o sistema instrução por instrução