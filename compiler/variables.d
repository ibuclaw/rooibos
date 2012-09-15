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

module compiler.variables;

import compiler.tokenizer;

import std.array;

// Structure used to keep track of the different breeds of variables during parsing.
struct Vars
{
  this (bool reserve = true)
  {
    if (reserve)
      {
	lexicals.reserve(32);
    	lexical_num.reserve(32);
      }
  }

  void pushFunction()
  {
    this.lexical_num ~= 0;
  }

  size_t popFunction()
  {
    size_t i = this.lexical_num.back();

    this.lexical_num.popBack();

    // Reduce the number of total lexicals by the number contained in the current function.
    this.lexical_total_num -= i;

    // Set the lexical variables for the current function to null (this holds their place in the indexing scheme).
    foreach_reverse(c, test; this.lexicals)
      {
	if (i == 0)
	  break;

	if (test != null)
	  {
	    this.lexicals[c].destroy();
	    i--;
	  }
      }

    // Clear the stack if there are no more lexicals.
    if (this.lexical_total_num == 0)
      {
	i = this.lexicals.length;
	this.lexicals.destroy();
	return i;
      }

    return 0;
  }

  size_t addLexical(Token* tok)
  {
      size_t ret = getLexical(tok);
      if (ret)
	return ret;

      this.lexicals ~= tok.str;
      this.lexical_num.back()++;
      this.lexical_total_num++;
      return this.lexicals.length;
  }

  size_t getLexical(Token* tok)
  {
    foreach_reverse(i, str; this.lexicals)
      {
	if (str && str == tok.str)
	  return i+1;
      }
    return 0;
  }

  string[] lexicals;	    // Stack of the variable names.
  size_t[] lexical_num;	    // Number of local lexical varaibles in this function.
  size_t lexical_total_num; // Total number of lexical variables in this function.
};

