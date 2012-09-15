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

module compiler.parser;

import compiler.tokenizer;
import compiler.variables;

import std.array;
import std.conv;
import std.string;
import std.stream;


enum : uint
{
  OPnop,
  OPintro,
  OPlabel,
  OPentry,
  OPpushsys,
  OPpushmodule,
  OPpushblock,
  OPpusharg,
  OPpushlex,
  OPpushargs,
  OPpushthis,
  OPpushself,
  OPpushvar,
  OPpushgvar,
  OPpushnum,
  OPpushstr,
  OPpusharray,
  OPpushtrapped,
  OPpushnull,
  OPline,
  OPjump,
  OPjit,
  OPjif,
  OPjifpop,
  OPjinc,
  OPpop,
  OPallocmodule,
  OPfreemodule,
  OPalloclocal,
  OPfreelocal,
  OPalloclexical,
  OPtypeof,
  OPstorearg,
  OPstorelex,
  OPstorechild,
  OPstoreattr,
  OPstoregvar,
  OPstorevar,
  OPlt,
  OPgt,
  OPeq,
  OPne,
  OPle,
  OPge,
  OPcmp,
  OPnot,
  OPand,
  OPor,
  OPtest,
  OPelse,
  OPtrap,
  OPneg,
  OPadd,
  OPsub,
  OPmult,
  OPdiv,
  OPmod,
  OPpow,
  OPgetattr,
  OPgetchild,
  OPdo,
  OPcall,
  OPcallchild,
  OPcallattr,
  OPdelattr,
  OPdelchild,
  OPreturn,
  OPraise,
  OPpause,
  OPstop,
  OPclear,
  OPend,
  OPmarker,
  OPmax
}
alias uint OPID;


// Opcode Atom.
struct Atom
{
  this (OPID id)
  {
    this.id = id;
    this.linenum = 0;
  }

  this (OPID id, size_t linenum)
  {
    this.id = id;
    this.linenum = linenum;
  }


  OPID id;
  size_t linenum;
  union
  {
    string str;
    size_t size;
    double number;
    void *pointer;
    int marker;
  }

  // Argument functions.
  void setString (Token *tok)
  { this.str = tok.str; }

  void setNumber (Token *tok)
  { this.number = tok.number; }

  void setPointer (void *pointer)
  { this.pointer = pointer; }

  void setSize (size_t size)
  { this.size = size; }

  void setMarkerType (int type)
  { this.marker = type; }
}

struct CData
{
  // Pushes operations onto the operations stack, but can delay the push
  // to ensure correct operator precedence by holding operator in the wait stack.
  void pushOp (Atom *input)
  {
    this.last = input.id;
    this.last_op = input;

    // 'pause', comma increments expression count and clears wait stack until marker.
    if (input.id == OPpause)
      {
	// Increment the expression count.
	if (this.expression_count.length)
	  this.expression_count.back()++;

	this.clearOps();
      }
    else if (op_info[input.id].right == 0)
      {
	// Immediate push into output without touching wait stack.
	this.output ~= input;
      }
    else
      {
	while (this.op_wait.length && (op_info[this.op_wait.back().id].left >= op_info[input.id].right))
	  this.transferOp();

	// Change call to specific call, and get rid of get_child and get_attr if necessary.
	if (input.id == OPmarker)
	  {
	    if (input.marker == OPcall)
	      {
		Atom *last = this.output.back();
		if (last.id == OPgetchild)
		  {
		    this.output.popBack();
		    input.marker = OPcallchild;
		  }
		else if (last.id == OPgetattr)
		  {
		    this.output.popBack();
		    input.marker = OPcallattr;
		  }
	      }
	  }

	this.op_wait ~= input;
      }
  }

  // Transfer ops on wait stack to the output.
  void clearOps()
  {
    while (this.op_wait.length && (this.op_wait.back().id != OPmarker))
      this.transferOp();
  }

  // Move op from wait stack to output.
  void transferOp()
  {
    Atom *op = this.op_wait.back();
    this.op_wait.popBack();

    if (op.id == OPor || op.id == OPand || op.id == OPelse || op.id == OPtrap)
      {
	// If there is not trap-expression put a NULL op in.
	if (op.id == OPtrap && this.last == OPjinc)
	  this.output ~= new Atom (OPpushnull);

	// change op type to LABEL (this is how some backpatching works).
	op.id = OPlabel;
      }
    else if (op.id == OPdelattr)
      {
	if (this.output.back().id == OPgetattr)
	  this.output.popBack();
	else if (this.output.back().id == OPgetchild)
	  {
	    this.output.popBack();
	    op.id = OPdelchild;
	  }
      }
    else if (op.id == OPtest)
      {
	Atom *label = new Atom (OPelse);

	this.output ~= new Atom (OPjump);
	this.output.back().setPointer (label);

	op.id = OPlabel;
	this.output ~= op;

	if (this.last != OPelse)
	  this.output ~= new Atom (OPpushnull);

	this.op_wait ~= label;
	return;
      }

    this.output ~= op;
  }

  string closeMarker()
  {
    Atom *marker;

    size_t expression_count = this.expression_count.back();

    // If you close the marker right after you open it the expression count is set to 0.
    if (this.last == OPmarker)
      expression_count = 0;

    // While data on the wait stack is not 'marker' transfer it to output.
    this.clearOps();

    // pop marker off of wait stack.
    if (this.op_wait.length && (this.op_wait.back().id == OPmarker))
      {
	marker = this.op_wait.back();
	this.op_wait.popBack();

	// Use the last value in the marker as the value.
	if (this.last == OPpop)
	  this.last_op.id = OPnop;

	switch (marker.marker)
	  {
    	  case OPpusharray:
	    Atom *op = new Atom (OPpusharray);
	    op.setSize (expression_count);
	    this.pushOp (op);
	    break;

	  case OPgetchild:
	  case OPcall:
	  case OPcallchild:
	  case OPcallattr:
	    Atom *op = new Atom (OPpusharray);
	    op.setSize (expression_count);
	    this.pushOp (op);

	    op = new Atom (marker.marker);
	    this.pushOp (op);

	    if (marker.marker != OPgetchild)
	      this.transferOp();
	    break;

	  case OPmarker:
	    if (expression_count == 0)
	      {
		Atom *op = new Atom (OPpushnull);
		this.pushOp (op);
	      }
	    break;

	  default:
	    return "Unknown Marker type";
    	  }
      }
    else
      {
	return "Mismatched Marker";
      }

    return null;
  }

  string error = null;		// an error message
  Atom*[] output;		// operators in correct order
  Atom*[] op_wait;		// stack used for operators waiting for precedence rules to enter output
  size_t[] expression_count;	// number of expressions between markers
  Atom* last_op = null;
  int last = OPend;
}

struct Operations
{
  string error = null;	// an error message
  Atom*[] output;	// operators ready for execution
}

enum : uint
{
  BLOCKdo,
  BLOCKfunction,
  BLOCKmodule,
  BLOCKloop
}
alias uint BLOCK;

struct OpInfo
{
  string name;
  int left;
  int right;
}

OpInfo[OPmax] op_info =
[
  { "$nop",		0,  0  },   // OPnop
  { "$intro",		0,  0  },   // OPintro
  { "$label",		0,  0  },   // OPlabel
  { "$label",		0,  0  },   // OPentry
  { "$pushsys",		0,  0  },   // OPpushsys
  { "$pushmodule",	0,  0  },   // OPpushmodule
  { "$pushblock",	0,  0  },   // OPpushblock
  { "$pusharg",		0,  0  },   // OPpusharg
  { "$pushlex",		0,  0  },   // OPpushlex
  { "$pushargs",	0,  0  },   // OPpushargs
  { "$pushthis",	0,  0  },   // OPpushthis
  { "$pushself",	0,  0  },   // OPpushself
  { "$pushvar",		0,  0  },   // OPpushvar
  { "$pushgvar",	0,  0  },   // OPpushgvar
  { "$pushnum",		0,  0  },   // OPpushnum
  { "$pushstr",		0,  0  },   // OPpushstr
  { "$pusharray",	0,  0  },   // OPpusharray
  { "$pushtrapped",	0,  0  },   // OPpushtrapped
  { "$pushnull",	0,  0  },   // OPpushnull
  { "#line",		0,  0  },   // OPline
  { "$jump",		0,  0  },   // OPjump
  { "$jit",		0,  0  },   // OPjit
  { "$jif",		0,  0  },   // OPjif
  { "$jifpop",		0,  0  },   // OPjifpop
  { "$jinc",		0,  0  },   // OPjinc
  { "$pop",		0,  0  },   // OPpop
  { "$allocmodule",	0,  0  },   // OPallocmodule
  { "$freemodule",	0,  0  },   // OPfreemodule
  { "$alloclocal",	0,  0  },   // OPalloclocal
  { "$freelocal",	0,  0  },   // OPfreelocal
  { "$alloclexical",	0,  0  },   // OPalloclexical
  { "$typeof",		0,  0  },   // OPtypeof
  { "$storearg",	0,  0  },   // OPstorearg
  { "$storelex",	0,  0  },   // OPstorelex
  { "$storechild",	0,  0  },   // OPstorechild
  { "$storeattr",	0,  0  },   // OPstoreattr
  { "$storegvar",	0,  0  },   // OPstoregvar
  { "$storevar",	0,  0  },   // OPstorevar
  { "$lt",		12, 12 },   // OPlt
  { "$gt",		12, 12 },   // OPgt
  { "$eq",		12, 12 },   // OPeq
  { "$ne",		12, 12 },   // OPne
  { "$le",		12, 12 },   // OPle
  { "$ge",		12, 12 },   // OPge
  { "$cmp",		12, 12 },   // OPcmp
  { "$not",		40, 40 },   // OPnot
  { "$and",		15, 15 },   // OPand
  { "$or",		15, 15 },   // OPor
  { "$test",		10, 11 },   // OPtest
  { "$else",		10, 11 },   // OPelse
  { "$trap",		4,  49 },   // OPtrap
  { "$neg",		40, 40 },   // OPneg
  { "$add",		20, 20 },   // OPadd
  { "$sub",		20, 20 },   // OPsub
  { "$mult",		30, 30 },   // OPmult
  { "$div",		30, 30 },   // OPdiv
  { "$mod",		30, 30 },   // OPmod
  { "$pow",		30, 31 },   // OPpow
  { "$getattr",		90, 89 },   // OPgetattr
  { "$getchild",	90, 89 },   // OPgetchild
  { "$do",		0,  0  },   // OPdo
  { "$call",		51, 51 },   // OPcall
  { "$callchild",	51, 51 },   // OPcallchild
  { "$callattr",	51, 51 },   // OPcallattr
  { "$delattr",		60, 60 },   // OPdelattr
  { "$delchild",	90, 89 },   // OPdelchild
  { "$return",		5,  16 },   // OPreturn
  { "$raise",		5,  16 },   // OPraise
  { "$pause",		0,  0  },   // OPpause
  { "$stop",		0,  0  },   // OPstop
  { "$clear",		0,  0  },   // OPclear
  { "$end",		0,  0  },   // OPend
  { "#error",		0,  90 }    // OPmarker
];


// Entry point for parsing operation.
Operations *parse_tokens(Tokens *tokens)
{
  Operations *ops = new Operations();

  // This is the storage for all the operations.
  ops.output.reserve (64);

  string[] globals = null;
  globals.reserve (32);

  // Reset the index for iterator.
  tokens.index = 0;

  // Add module allocation op for global variables.
  Atom *alloc_module = new Atom (OPallocmodule);
  alloc_module.setSize (0);
  ops.output ~= alloc_module;

  // Add a jump to the entry point for this module.
  Atom *op = new Atom (OPjump);
  op.setPointer (tokens.tokens[0]);
  ops.output ~= op;

  Vars *variables = new Vars();

  ops.error = parse (tokens, ops.output, variables, globals, null, null, BLOCKmodule);

  alloc_module.setSize (globals.length);

  globals.destroy();
  variables.destroy();

  return ops;
}


// token_stack:	The tokens that make up the program.
// output:	The generated opcodes.
// globals:	All the global variables.
// locals:	The current local variables.
// arguments:	The named arguments.

string parse(ref Tokens *token_stack, ref Atom*[] output, ref Vars *variables, ref string[] globals,
	     string[] locals, string[] arguments, BLOCK block_type)
{
  string ATOM()(OPID id)
  {
    return "op = new Atom ("~to!string(id)~", token.linenum);"~
	   "cdata.pushOp (op);";
  }

  string ATOM_LABEL()(OPID id)
  {
    return "label = new Atom ("~to!string(id)~", token.linenum);"~
	   "cdata.pushOp (label);";
  }

  Atom *op = null;
  Atom *label = null;

  string error = null;
  size_t index = 0;

  // Create a new compiler data object.
  CData *cdata = new CData();
  cdata.output.reserve (64);
  cdata.op_wait.reserve (64);
  cdata.expression_count.reserve (64);

  Token *token = token_stack.tokens[token_stack.index];
  Token *token_last = null;
  //string_t err = null;

  Atom *alloc_local = null;
  Atom *alloc_lexical = null;

  // Add the entry point for this function.
  mixin (ATOM (OPentry));
  op.setPointer (token);

  variables.pushFunction();

  if (!locals)
    {
      arguments.reserve (32);
      locals.reserve (32);
      alloc_local = new Atom (OPalloclocal);
      cdata.pushOp (alloc_local);
      alloc_local.setSize (0);
    }

  while (token_stack.index < token_stack.tokens.length)
    {
      token = token_stack.tokens[token_stack.index];

      switch (token.type)
	{
	case TOKor:
	  // Create 'or' label.
	  mixin (ATOM_LABEL (OPor));

	  // Push jump if true onto command queue.
	  mixin (ATOM (OPjit));
	  op.setPointer (label);
	  // Add pop to command queue.
	  mixin (ATOM (OPpop));
	  break;

	case TOKand:
	  // Create 'and' label.
	  mixin (ATOM_LABEL (OPand));
	  // Push jump if false onto command queue.
	  mixin (ATOM (OPjif));
	  op.setPointer (label);
	  // Add pop to command queue.
	  mixin (ATOM (OPpop));
	  break;

	case TOKdel:
	  mixin (ATOM (OPdelattr));
	  break;

	case TOKsys:
	  mixin (ATOM (OPpushsys));
	  break;

	case TOKpipe:
	case TOKtrap:
	  // Create and add 'trap' label to the wait stack.
	  mixin (ATOM_LABEL (OPtrap));
	  // Push jump if not critical onto ouput.
	  mixin (ATOM (OPjinc));
	  op.setPointer (label);
	  break;

	case TOKargs:
	  mixin (ATOM (OPpushargs));
	  break;

	case TOKthis:
	  mixin (ATOM (OPpushthis));
	  break;

	case TOKself:
	  mixin (ATOM (OPpushself));
	  break;

	case TOKraise:
	  // Clear the execution stack for the return value.
	  // If all thats on the op stack is the entry you don't need to clear anything.
	  if (cdata.output.length == 1)
	    {
	      op = cdata.output.back();
	      if (op.id == OPpop)
		{
		  // Replace pop with clear.
		  op.id = OPclear;
		}
	      else
		{
		  // Add a clear for normal return.
		  cdata.output ~= new Atom (OPclear, token.linenum);
		}
	    }
	  mixin (ATOM (OPraise));
	  break;

	case TOKreturn:
	  // Clear the execution stack for the return value.
	  // If all thats on the op stack is the entry you don't need to clear anything.
	  if (cdata.output.length == 1)
	    {
	      op = cdata.output.back();
	      if (op.id == OPpop)
		{
		  // Replace pop with clear.
		  op.id = OPclear;
		}
	      else
		{
		  // Add a clear for normal return.
		  cdata.output ~= new Atom (OPclear, token.linenum);
		}
	    }
	  mixin (ATOM (OPreturn));
	  break;

	case TOKglobal:
	case TOKlexical:
	  break;

	case TOKat:
	case TOKtrapped:
	  mixin (ATOM (OPpushtrapped));
	  break;

	case TOKend:
	  cdata.clearOps();
	  mixin (ATOM (OPend));
	  goto Ldone;

	case TOKsemicolon:
	  cdata.clearOps();

	  switch (cdata.output.back().id)
	    {
	    case OPpushgvar:	case OPpushvar:
	    case OPpushlex:	case OPpusharg:
	      // The var/arg will not be pushed onto the stack.
	      cdata.output.popBack();
    	      cdata.last = OPpop;
	      break;

	    case OPreturn:
	      // Don't need to pop if returning.
	      break;

	    default:
	      mixin (ATOM (OPpop));
	      break;
	    }
	  break;

	case TOKdot:
	  mixin (ATOM (OPgetattr));
	  break;

	case TOKplus:
	  mixin (ATOM (OPadd));
	  break;

	case TOKminus:
	  switch (cdata.last)
	    {
	    case OPpushvar:
	    case OPpushgvar:
	    case OPpusharg:
	    case OPpushlex:
	    case OPcall:
	    case OPcallattr:
	    case OPcallchild:
	    case OPgetattr:
	    case OPgetchild:
	      mixin (ATOM (OPsub));
	      break;

	    default:
	      mixin (ATOM (OPneg));
	      break;
	    }
	  break;

	case TOKmult:
	  mixin (ATOM (OPmult));
	  break;

	case TOKdiv:
	  mixin (ATOM (OPdiv));
	  break;

	case TOKpercent:
	  mixin (ATOM (OPmod));
	    break;

	case TOKhat:
	  mixin (ATOM (OPpow));
	  break;

	case TOKcomma:
	  mixin (ATOM (OPpause));
	  break;

	case TOKquestion:
	  // Create 'test' label.
	  mixin (ATOM_LABEL (OPtest));

	  // Push jump if false onto command queue.
	  mixin (ATOM (OPjifpop));
	  op.setPointer (label);
	  break;

	case TOKcolon:
	  if (token_last.type == TOKquestion)
	    {
	      mixin (ATOM (OPpushnull));
	    }
	  cdata.last = OPelse;

	  while (cdata.op_wait.length && (cdata.op_wait.back().id != OPtest))
	    cdata.transferOp();
	  break;

	case TOKequal:
	  if (cdata.last == OPpushgvar)
	    {
	      op = cdata.output.back();
	      cdata.output.popBack();
	      op.id = OPstoregvar;
	      cdata.pushOp (op);
	      break;
	    }
	  else if (cdata.last == OPpushvar)
	    {
	      op = cdata.output.back();
	      cdata.output.popBack();
	      op.id = OPstorevar;
	      cdata.pushOp (op);
	      break;
	    }
	  else if (cdata.last == OPpusharg)
	    {
	      op = cdata.output.back();
	      cdata.output.popBack();
	      op.id = OPstorearg;
	      cdata.pushOp (op);
	      break;
	    }
	  else if (cdata.last == OPpushlex)
	    {
	      op = cdata.output.back();
	      cdata.output.popBack();
	      op.id = OPstorelex;
	      cdata.pushOp (op);
	      break;
	    }
	  else if (cdata.op_wait.length)
	    {
	      op = cdata.op_wait.back();
	      cdata.op_wait.popBack();
	    }
	  else if (cdata.output.length)
	    {
	      op = cdata.output.back();
	      cdata.output.popBack();
	    }

	  switch (op.id)
	    {
	    case OPgetchild:
	      mixin (ATOM (OPstorechild));
	      break;

	    case OPgetattr:
	      mixin (ATOM (OPstoreattr));
	      break;

	    default:
	      cdata.output ~= op;
	      break;
	    }
	  break;

	case TOKampand:
	  mixin (ATOM (OPtypeof));
	  break;

	case TOKeq:
	  mixin (ATOM (OPeq));
	  break;

	case TOKlt:
	  mixin (ATOM (OPlt));
	  break;

	case TOKle:
	  mixin (ATOM (OPle));
	  break;

	case TOKgt:
	  mixin (ATOM (OPgt));
	  break;

	case TOKge:
	  mixin (ATOM (OPge));
	  break;

	case TOKcompare:
	  mixin (ATOM (OPcmp));
	  break;

	case TOKexclamation:
	  mixin (ATOM (OPnot));
	  break;

	case TOKne:
	  mixin (ATOM (OPne));
	  break;

	case TOKlparen:
	  switch (cdata.last)
	    {
	    case OPpusharg:	case OPpushlex:
	    case OPpushthis:	case OPpushself:
	    case OPpushvar:	case OPpushgvar:
	    case OPcall:	case OPpushblock:
	    case OPgetchild:	case OPgetattr:
	      // Standard call.
	      op = new Atom (OPmarker);
	      op.setMarkerType (OPcall);
	      cdata.expression_count ~= 1;
	      break;

	    default:
	      // Precedence modifier.
	      op = new Atom (OPmarker);
	      op.setMarkerType (OPmarker);
	      cdata.expression_count ~= 1;
	      break;
	    }
	  cdata.pushOp (op);
	  break;

	case TOKrparen:
	  error = cdata.closeMarker();
	  if (error)
	    {
	      error = format ("%s  line: %s", error, token.linenum);
	      goto Ldone;
	    }
	  break;

	case TOKlbracket:
	  switch (cdata.last)
	    {
	    case OPentry:	case OPpop:
	    case OPpause:	case OPstorelex:
	    case OPstoreattr:	case OPstorechild:
	    case OPstorevar:	case OPstoregvar:
	    case OPraise:	case OPreturn:
	    case OPtypeof:	case OPnot:
	    case OPlt:		case OPgt:
	    case OPeq:		case OPne:
	    case OPle:		case OPge:
	    case OPand:		case OPor:
	    case OPadd:		case OPsub:
	    case OPmult:	case OPdiv:
	    case OPmod:		case OPpow:
	    case OPmarker:
	      mixin (ATOM (OPmarker));
	      op.setMarkerType (OPpusharray);
	      cdata.expression_count ~= 1;
	      break;

	    default:
	      mixin (ATOM (OPmarker));
	      op.setMarkerType (OPgetchild);
	      cdata.expression_count ~= 1;
	      break;
	    }
	  break;

	case TOKrbracket:
	  error = cdata.closeMarker();
	  if (error)
	    {
	      error = format ("%s  line %s", error, token.linenum);
	      goto Ldone;
	    }
	  break;

	case TOKstartblock:
	  if (!token.str || (token.str == "do"))
	    {
	      // Do block.
	      mixin (ATOM (OPdo));

	      // Get the first token inside of the block.
	      token = token_stack.tokens[++token_stack.index];

	      // Set the 'do' op argument to this token position.
	      op.setPointer (token);

	      error = parse (token_stack, output, variables, globals, locals, arguments, BLOCKdo);
	      if (error)
		{
		  error = format ("%s  line: %s", error, token.linenum);
		  goto Ldone;
		}
	    }
	  else if (token.str == "func")
	    {
	      // Function block.
	      mixin (ATOM (OPpushblock));

	      token = token_stack.tokens[++token_stack.index];
	      op.setPointer (token);

	      error = parse (token_stack, output, variables, globals, null, null, BLOCKfunction);
	      if (error)
		{
		  error = format ("%s  line: %s", error, token.linenum);
		  goto Ldone;
		}
	    }
	  else if (token.str == "loop")
	    {
	      // Loop block.
	      mixin (ATOM (OPdo));

	      token = token_stack.tokens[++token_stack.index];
	      op.setPointer (token);

	      error = parse (token_stack, output, variables, globals, locals, arguments, BLOCKloop);
	      if (error)
		{
		  error = format ("%s  line: %s", error, token.linenum);
		  goto Ldone;
		}

	      // Add the jump that makes the code a loop.
	      op = output.back();
	      // Change the 'end' op to a 'jump'.
	      op.id = OPjump;
	      op.setPointer (token);
	    }
	  break;

	case TOKendblock:
	  cdata.clearOps();
	  mixin (ATOM (OPend));
	  goto Ldone;

	case TOKarg:
	    break;

	case TOKidentifier:
	    if (token_last && token_last.type == TOKdot)
	      {
		// Member
		mixin (ATOM (OPpushstr));
		op.setString (token);
		cdata.last = OPgetattr;
	      }
	    else if (token_last && token_last.type == TOKglobal)
	      {
		// Global
		index = addString (globals, token);
		mixin (ATOM (OPpushgvar));
		op.setSize (index - 1);
	      }
	    else if (token_last && token_last.type == TOKarg)
	      {
		// Arg
		index = addString (arguments, token);
		mixin (ATOM (OPpusharg));
		op.setSize (index - 1);
	      }
	    else if (token_last && token_last.type == TOKlexical)
	      {
		// Lex
		index = variables.addLexical (token);
		if (index == 1)
		  {
		    // This is the first lexical var.
		    alloc_lexical = new Atom (OPalloclexical);
		    alloc_lexical.setSize (0);
		    cdata.pushOp (alloc_lexical);

		    mixin (ATOM (OPpushlex));
		    op.setSize (index - 1);
		  }
	      }
	    else if ((index = findString (arguments, token)) != 0)
	      {
		// Arg predefined
		mixin (ATOM (OPpusharg));
		op.setSize (index - 1);
	      }
	    else if ((index = findString (globals, token)) != 0)
	      {
		// Global predefined
		mixin (ATOM (OPpushgvar));
		op.setSize (index - 1);
	      }
	    else if ((index = variables.getLexical (token)) != 0)
	      {
		// Lexical predefined
		mixin (ATOM (OPpushlex));
		op.setSize (index - 1);
	      }
	    else
	      {
		// Local
		index = addString (locals, token);
		mixin (ATOM (OPpushvar));
		op.setSize (index - 1);
	      }
	    break;

	case TOKstring:
	    mixin (ATOM (OPpushstr));
	    op.setString (token);
	    break;

	case TOKnumber:
	    mixin (ATOM (OPpushnum));
	    op.setNumber (token);
	    break;

	default:
	    assert (0);
	}

      token_stack.index++;
      token_last = token;
    }

Ldone:
  cdata.clearOps();

  if (alloc_local)
    {
      alloc_local.setSize (locals.length);
      locals.destroy();
      arguments.destroy();
    }

  output ~= cdata.output;
  cdata.destroy();

  index = variables.popFunction();
  if (index)
     alloc_lexical.setSize (index);

  return error;
}


void printOperations(Operations *ops, Stream stream, bool debug_data)
{
  size_t linenum = 0;

  foreach (op; ops.output)
    {
      // Add the debugging data.
      if (debug_data)
	{
	  // Don't print the linenum op right after a label or entry or jinc.
	  if (op.linenum && op.linenum != linenum
	      && op.id != OPlabel && op.id != OPentry && op.id != OPjinc)
	    {
	      stream.writefln("%s %s", op_info[OPline].name, op.linenum);
	      linenum = op.linenum;
	    }
	}

      switch (op.id)
	{
	case OPnop:
	  break;

	case OPallocmodule:
	case OPalloclocal:
	case OPalloclexical:
	  // OPs with size arguments that print only when size != 0.
	  if (op.size)
	    stream.writefln("%s %s", op_info[op.id].name, op.size);
	  break;

	case OPpusharray:	case OPpushgvar:
	case OPpushvar:		case OPpusharg:
	case OPpushlex:		case OPstoregvar:
	case OPstorevar:	case OPstorearg:
	case OPstorelex:
	  // OPs with size arguments.
	  stream.writefln("%s %s", op_info[op.id].name, op.size);
	  break;

	case OPpushnum:
	  // OPs with number arguments.
	  stream.writefln("%s %s", op_info[op.id].name, op.number);
	  break;

	case OPpushstr:
	  // OPs with string arguments.
	  stream.writefln("%s \"%s\"", op_info[op.id].name, op.str);
	  break;

	case OPdo:	case OPpushblock:
	case OPentry:	case OPjump:
	case OPjit:	case OPjif:
	case OPjifpop:	case OPjinc:
	  // OPs with label arguments.
	  stream.writefln("%s %s", op_info[op.id].name, op.pointer);
	  break;

	case OPlabel:
	  stream.writefln("%s %s", op_info[op.id].name, op);
	  break;

	default:
	  stream.writefln("%s", op_info[op.id].name);
	  break;
	}
    }

  // Set output back to start.
  stream.position = 0;
}


size_t findString(string[] strings, Token *tok)
{
  foreach (i, str; strings)
    {
      if (str == tok.str)
	return i + 1;
    }
  return 0;
}

size_t addString(ref string[] strings, Token *tok)
{
  size_t ret = findString (strings, tok);
  if (!ret)
    {
      strings ~= tok.str;
      return strings.length;
    }
  return ret;
}


