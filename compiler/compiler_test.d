// The Rooibos programming language ("rooibos")
// Copyright (C) 2012  Iain Buclaw

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program; If not see <http://www.gnu.org/licenses/>.

module compiler.test;

import compiler.tokenizer;
import compiler.parser;
import compiler.assembler;
import compiler.decompile;

import std.file;
import std.outbuffer;
import std.stream;
import std.stdio;

int main(string[] args)
{
  if (args.length != 2)
    {
      stderr.writefln("Usage: %s file", args[0]);
      return 1;
    }

  string source = cast(string) read(args[1]);
  Stream output = new MemoryStream();

  Tokens* toks = tokenize (source);
  if (toks.error)
    {
      stderr.writeln(toks.error);
      return 1;
    }

  Operations* ops = parse_tokens(toks);
  if (ops.error)
    {
      stderr.writeln(ops.error);
      return 1;
    }
  printOperations(ops, output, true);

  OutBuffer bytecode = assemble(output);

  string disassembly = disassemble(bytecode);

  writeln("========== Tokens ==========");
  printTokens(toks);
  writeln("========== Assembly ==========");
  writeln(output.toString());
  writeln("========== Bytecode ==========");
  writeln(bytecode.toBytes());
  writeln("========== Disassembly ==========");
  writeln(disassembly);

  output.destroy();
  toks.destroy();
  source.destroy();
  ops.destroy();

  return 0;
}

