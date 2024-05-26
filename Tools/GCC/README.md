# :package: GCC: Build Instructions
In this folder should reside a _i386-elf_ build of **Binutils** and **GCC**. These instructions follow the ones provided by the very smart people at OSDev (https://wiki.osdev.org/GCC_Cross-Compiler) targeting a Windows system using a MSYS2 environment.

## Setting up the Environment
1) Install tooling

In order to build native Windows compiler executables, we need the **MSYS2** building environment. You can obtain it in here https://www.msys2.org/.

After installing **MSYS2**, we'll need a few dependencies installed to compile Binutils and GCC. In the **UCRT64** shell, install the following dependencies using **pacman**

```
> pacman -S mingw-w64-ucrt-x86_64-gcc make texinfo base-devel gmp mpc mpfr
```

2) Setup source code

Download the source code of Binutils and GCC tar files.

In MSYS2 UCRT64 environment, setup the required folders and environment variables

```
> export PREFIX="$HOME/opt/cross"
> export TARGET=i386-elf
> export PATH="$PREFIX/bin:$PATH"
```

## Compiling Binutils
```
> cd $HOME/src

> mkdir build-binutils
> cd build-binutils
> ../binutils-x.y.z/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
> make
> make install
```

## Compiling GCC
```
> cd $HOME/src

> mkdir build-gcc
> cd build-gcc
> ../gcc-x.y.z/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers
> make all-gcc
> make all-target-libgcc
> make install-gcc
> make install-target-libgcc
```
