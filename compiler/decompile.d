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

module compiler.decompile;

import compiler.parser;

import std.outbuffer;
import std.string;


string disassemble(OutBuffer bytecode)
{
  string[] str_stack;
  str_stack.reserve (32);
  string buffer;

  ubyte *current = bytecode.data.ptr;
  ubyte *end = &bytecode.data[$];

  while (current < end)
    {
      switch (*current)
	{
	case OPintro:
	  buffer = format ("0x%.6x %s", (current - bytecode.data.ptr),
			   op_info[*current].name);
	  current += 5;
	  str_stack ~= buffer;
	  break;

	case OPallocmodule:
	case OPalloclocal:
	case OPalloclexical:
	case OPline:
	case OPpusharg:
	case OPdo:
	case OPpushblock:
	case OPpusharray:
	case OPpushgvar:
	case OPpushlex:
	case OPpushvar:
	case OPstorearg:
	case OPstorevar:
	case OPstoregvar:
	case OPstorelex:
	case OPjit:
	case OPjif:
	case OPjifpop:
	case OPjump:
	case OPjinc:
	  buffer = format ("0x%.6x %s", (current - bytecode.data.ptr),
			   op_info[*current].name);
	  current++;
	  buffer = format ("%s %s", buffer, *(cast(size_t *) current));
	  current += size_t.sizeof;
	  str_stack ~= buffer;
	  break;

	case OPpushnum:
	  buffer = format ("0x%.6x %s", (current - bytecode.data.ptr),
			   op_info[*current].name);
	  current++;
	  buffer = format ("%s %g", buffer, *(cast(double *) current));
	  current += double.sizeof;
	  str_stack ~= buffer;
	  break;

	case OPpushstr:
	  buffer = format ("0x%.6x %s", (current - bytecode.data.ptr),
			   op_info[*current].name);
	  current++;
	  size_t *plen = cast(size_t *)(bytecode.data.ptr + *(cast(size_t *) current));
	  char *ptr = cast(char *)(plen + 1);
	  buffer = format ("%s %s", buffer, cast(string)(ptr[0 .. *plen]));
	  current += size_t.sizeof;
	  str_stack ~= buffer;
	  break;

	case OPpause:
	  return str_stack.join("\n");

	default:
	  buffer = format ("0x%.6x %s", (current - bytecode.data.ptr),
			   op_info[*current].name);
	  current++;
	  str_stack ~= buffer;
	}
    }

  assert (false);
}


