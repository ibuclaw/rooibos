## The Rooibos programming language ("rooibos")
## Copyright (C) 2012  Iain Buclaw

## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with this program; If not see <http://www.gnu.org/licenses/>.

DC=gdc
DFLAGS=-g
#DFLAGS=-g -O2 -frelease

COMPILER_OBJECTS = compiler/assembler.o compiler/decompile.o \
		   compiler/parser.o compiler/syntax.o \
		   compiler/tokenizer.o compiler/variables.o

#MAIN_OBJECTS = main.o
MAIN_OBJECTS = compiler/compiler_test.o

all: rbos

# source/object dependencies
compiler/assembler.o: compiler/parser.d
compiler/decompile.o: compiler/parser.d
compiler/parser.o: compiler/tokenizer.d compiler/variables.d
compiler/syntax.o: compiler/tokenizer.d
compiler/tokenizer.o: compiler/syntax.d
compiler/variables.o: compiler/tokenizer.d


# Main build / clean routines
rbos: $(MAIN_OBJECTS) $(COMPILER_OBJECTS)
	$(DC) -o $@ $(DFLAGS) $(MAIN_OBJECTS) $(COMPILER_OBJECTS)

%.o: %.d
	$(DC) -o $@ $(DFLAGS) -c $<

clean:
	rm -f rbos $(COMPILER_OBJECTS) $(MAIN_OBJECTS)


