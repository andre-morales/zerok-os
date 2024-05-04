## Environment
1) Install tooling

Use MSYS2 environment to build native windows executables, In MSYS2, install the following dependencies using pacman

```
pacman -S mingw-w64-ucrt-x86_64-gcc make texinfo base-devel gmp mpc mpfr
```

2) Setup source code

Download the source code of Binutils and GCC

In MSYS2 UCRT64 environment, setup the required folders and environment variables

```
export PREFIX="$HOME/opt/cross"
export TARGET=i386-elf
export PATH="$PREFIX/bin:$PATH"
```

## Compiling Binutils
```
cd $HOME/src

mkdir build-binutils
cd build-binutils
../binutils-x.y.z/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
make
make install
```

## Compiling GCC
```
cd $HOME/src

mkdir build-gcc
cd build-gcc
../gcc-x.y.z/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers
make all-gcc
make all-target-libgcc
make install-gcc
make install-target-libgcc
```
