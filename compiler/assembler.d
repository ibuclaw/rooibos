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

module compiler.assembler;

import compiler.parser;

import std.array;
import std.ascii;
import std.conv;
import std.outbuffer;
import std.stream;


struct Label
{
  this (string name, size_t offset)
  {
    this.name = name;
    this.offset = offset;
  }

  string name;
  size_t offset;
}

struct Node
{
  this (size_t offset)
  {
    this.offset = offset;
  }

  size_t offset;
}

// Assemble assembly code into bytecode
OutBuffer assemble(Stream stream)
{
  // String constant storage.
  string[] string_const;
  string_const.reserve (16);

  // Variables used in the far too complex string backpatching section.
  Node*[] string_backpatch = null;

  // Create stacks for handling jumps and matching labels.
  Label*[] labels;
  Label*[] jumps;
  labels.reserve (64);
  jumps.reserve (64);

  // Main storage mechanism for the output.
  OutBuffer output = new OutBuffer();

  // Assembly signature.
  output.write(cast(ubyte) OPintro);
  output.write(cast(ubyte[4]) [35, 33, 0, 0]);

  while (1)
    {
      // Read a line and skip whitespaces.
      string line = cast(string) stream.readLine();
      if (line.empty())
	break;

      size_t len = 1;
      while (len < line.length && line[len].isAlpha())
	len++;

      string opcode = line[0 .. len];
      string operand = line[len + (len < line.length ? 1 : 0) .. $];
      assert(opcode[0] == '$' || opcode[0] == '#');

      // If compilation had errors.
      if (opcode == "#error")
	{
	  output = new OutBuffer();
	  output.write(cast(ubyte) OPintro);
	  output.write(cast(ubyte[4]) [35, 33, 0, 1]);
	  output.write(opcode);
	  goto Ldone;
	}

      // Get the opcode and return its numerical value.
      OPID opid = getOpId (opcode);

      // Write the bytecode equivalent of the opcode.
      switch (opid)
	{
	case OPlabel:
	  // Mark the current location in the label stack.
	  labels ~= new Label (operand, output.offset);
	  break;

	case OPdo:
	case OPpushblock:
	case OPjump:
	case OPjif:
	case OPjifpop:
	case OPjit:
	case OPjinc:
	  // Write the opcode and prepare for a reference backpatch.
	  output.write (cast(ubyte) opid);
	  jumps ~= new Label (operand, output.offset);
	  output.write (cast(size_t) null);
	  break;

	case OPpushstr:
	  size_t index = addStringConst (string_const, operand);
	  output.write (cast(ubyte) opid);
	  // Add the strings to the backpatch linked list.
	  string_backpatch ~= new Node (output.offset);
	  output.write (index);
	  break;

	case OPpushnum:
	  output.write (cast(ubyte) opid);
	  output.write (to!double(operand));
	  break;

	case OPpusharray:
	case OPalloclocal:
	case OPalloclexical:
	case OPallocmodule:
	case OPpusharg:
	case OPpushlex:
	case OPpushgvar:
	case OPpushvar:
	case OPstorearg:
	case OPstorelex:
	case OPstoregvar:
	case OPstorevar:
	case OPline:
	  output.write (cast(ubyte) opid);
	  output.write (to!size_t(operand));
	  break;

	default:
	  output.write (cast(ubyte) opid);
	  break;
	}
    }

Ldone:

  // Write the opcode that signals the end of the code section.
  output.write (cast(ubyte) OPpause);

  // String constants and backpatching.
  foreach (index, str; string_const)
    {
      // Loop through all of the strings that need to be backpatched.
      foreach (ref patch; string_backpatch)
	{
	  if (patch == null)
	    continue;

	  // pindex is a pointer to the $pushstr argument, currently it holds
	  // the index of the desired string in the string_const stack.
	  size_t * pindex = cast(size_t *)(output.data.ptr + patch.offset);

	  // The current string matches the index of the string that needs to be backpatched.
	  if (*pindex == index)
	    {
	      // Set the value of pindex to the position in the bytecode,
	      // instead of the temporary index currently stored there.
	      *pindex = output.offset;

	      // delete the resolved backpatch.
	      patch.destroy();
	      continue;
	    }
	}

      while (!string_backpatch.empty() && !string_backpatch[0])
	string_backpatch.popFront();

      output.write (str.length);
      output.write (str);
    }

  // Jumps.
  foreach (jump; jumps)
    {
      foreach (label; labels)
	{
	  if (label.name == jump.name)
	    {
	      size_t *pindex = cast(size_t *)(output.data.ptr + jump.offset);
	      *pindex = label.offset;
	      break;
	    }
	}
    }

  labels.destroy();
  jumps.destroy();
  string_const.destroy();

  return output;
}

// Searches the Atom info and finds the integer id that matches the opcode.
OPID getOpId(string opcode)
{
  for (OPID op = 0; op < OPend; op++)
    {
      if (op_info[op].name == opcode)
	return op;
    }
  return OPend;
}


size_t addStringConst(ref string[] string_const, string str)
{
  // Test for redundancy.
  foreach (index, line; string_const)
    {
      if (line == str)
	return index;
    }
  string_const ~= str;
  return string_const.length - 1;
}


