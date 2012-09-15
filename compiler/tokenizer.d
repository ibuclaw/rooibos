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

module compiler.tokenizer;

import compiler.syntax;

import std.array;
import std.ascii;
import std.conv;
import std.stdio;

enum : uint
{
  TOKor,	    //  or
  TOKand,	    //  and
  TOKdel,	    //  del
  TOKsys,	    //  sys
  TOKtrap,	    //  trap
  TOKargs,	    //  args
  TOKarg,	    //  arg
  TOKthis,	    //  this
  TOKself,	    //  self
  TOKraise,	    //  raise
  TOKreturn,	    //  return
  TOKglobal,	    //  global
  TOKlexical,	    //  lexical
  TOKtrapped,	    //  trapped
  TOKsemicolon,	    //  ;
  TOKdot,	    //  . 
  TOKplus,	    //  +
  TOKminus,	    //  -
  TOKmult,	    //  *
  TOKdiv,	    //  /
  TOKpercent,	    //  %
  TOKhat,	    //  ^
  TOKcomma,	    //  ,
  TOKquestion,	    //  ?
  TOKcolon,	    //  :
  TOKequal,	    //  =
  TOKampand,	    //  &
  TOKpipe,	    //  |
  TOKat,	    //  @
  TOKeq,	    //  ==
  TOKlt,	    //  <
  TOKle,	    //  <=
  TOKgt,	    //  >
  TOKge,	    //  >=
  TOKcompare,	    //  <>
  TOKexclamation,   //  !
  TOKne,	    //  !=
  TOKlparen,	    //  (
  TOKrparen,	    //  )
  TOKlbracket,	    //  [
  TOKrbracket,	    //  ]
  TOKstartblock,    //  {
  TOKendblock,	    //	}
  TOKidentifier,    //	foo
  TOKstring,	    //	"bar"
  TOKnumber,	    //	123.456
  TOKend,	    //	EOF
}
alias uint TOK;

struct Token
{
  this (TOK type, size_t linenum)
  {
    this.type = type;
    this.linenum = linenum;
    this.str = null;
  }

  TOK type;
  size_t linenum;
  union
  {
    string str;
    double number;
    size_t size;
  }
}

struct Tokens
{
  this (string source)
  {
    this.error = null;
    this.current = source;
    this.tokens.reserve (64);
    this.linenum = 1;
  }

  string error;	    // an error message
  string current;   // the location in the source code that we are currently parsing
  Token*[] tokens;  // stack containing tokens
  size_t linenum;
  size_t index;	    // index into the token_stack
}

Tokens *tokenize(string source)
{
  string SYNTAX()()
  {
    return "{ tokens.error = syntax_check (tokens, token);"~
	   "  if (tokens.error != null)"~
	   "    return tokens;"~
	   "}";
  }

  string TOKEN()(TOK tok)
  {
    return "{ token = new Token ("~to!string(tok)~", tokens.linenum);"~
	   "  mixin (SYNTAX);"~
	   "  tokens.tokens ~= token;"~
	   "}";
  }

  string KEYWORD()(string key, TOK tok)
  {
    return "if (\""~(key)~"\" == tokens.current[0 .. len]) {"~
	   "  mixin (TOKEN ("~to!string(tok)~"));"~
	   "  tokens.current = tokens.current[len .. $];"~
	   "  continue;"~
	   "}";
  }

  string OPERATOR()(char key, TOK tok)
  {
    return "case '"~(key)~"':"~
	   "  mixin (TOKEN ("~to!string(tok)~"));"~
	   "  tokens.current.popFront();"~
	   "  continue;";
  }

  string OPERATOR2()(char key, char key2, TOK tok, TOK tok2)
  {
    return "case '"~(key)~"':"~
	   "  if (tokens.current[1] == '"~(key2)~"') {"~
	   "    mixin (TOKEN ("~to!string(tok2)~"));"~
	   "    tokens.current.popFront();"~
	   "  }"~
	   "  else"~
	   "    mixin (TOKEN ("~to!string(tok)~"));"~
	   "  tokens.current.popFront();"~
	   "  continue;";
  }

  string OPERATOR3()(char key, char key2, char key3, TOK tok, TOK tok2, TOK tok3)
  {
    return "case '"~(key)~"':"~
	   "  if (tokens.current[1] == '"~(key2)~"') {"~
	   "    mixin (TOKEN ("~to!string(tok2)~"));"~
	   "    tokens.current.popFront();"~
	   "  }"~
	   "  else if (tokens.current[1] == '"~(key3)~"') {"~
	   "    mixin (TOKEN ("~to!string(tok3)~"));"~
	   "    tokens.current.popFront();"~
	   "  }"~
	   "  else"~
	   "    mixin (TOKEN ("~to!string(tok)~"));"~
	   "  tokens.current.popFront();"~
	   "  continue;";
  }

  Tokens *tokens = new Tokens (source);
  Token *token;

  while (!tokens.current.empty())
    {
      // Ignore whitespace.
      while (tokens.current[0].isWhite() && tokens.current[0] != '\n')
	tokens.current.popFront();

      if (tokens.current.empty())
	break;

      // Letters.
      if (tokens.current[0].isAlpha() || tokens.current[0] == '_')
	{
	  size_t len = 1;
	  while (tokens.current[len].isAlphaNum() || tokens.current[len] == '_')
	    len++;

	  // Keywords.
	  switch (len)
	    {
	    case 2:
	      mixin (KEYWORD ("or", TOKor));
	      break;

	    case 3:
	      mixin (KEYWORD ("and", TOKand));
	      mixin (KEYWORD ("del", TOKdel));
	      mixin (KEYWORD ("arg", TOKarg));
	      mixin (KEYWORD ("sys", TOKsys));
	      break;

	    case 4:
	      mixin (KEYWORD ("trap", TOKtrap));
	      mixin (KEYWORD ("args", TOKargs));
	      mixin (KEYWORD ("this", TOKthis));
	      mixin (KEYWORD ("self", TOKself));
	      break;

	    case 5:
	      mixin (KEYWORD ("raise", TOKraise));
	      break;

	    case 6:
	      mixin (KEYWORD ("return", TOKreturn));
	      mixin (KEYWORD ("global", TOKglobal));
	      break;

	    case 7:
	      mixin (KEYWORD ("trapped", TOKtrapped));
	      mixin (KEYWORD ("lexical", TOKlexical));
	      break;

	    default:
	      break;
	    }

	  // Identifiers.
	  mixin (TOKEN (TOKidentifier));
	  token.str = tokens.current[0 .. len];
	  tokens.current = tokens.current[len .. $];
	  continue;
	}

      // Numbers.
      if (tokens.current[0].isDigit()
	  || tokens.current[0] == '.' && tokens.current[1].isDigit())
	{
	  size_t len = 1;
	  while (tokens.current[len].isDigit() || tokens.current[len] == '.')
	    len++;

	  mixin (TOKEN (TOKnumber));
	  token.number = to!double(tokens.current[0 .. len]);
	  tokens.current = tokens.current[len .. $];
	  continue;
	}

      // Strings.
      if (tokens.current[0] == '"')
	{
	  mixin (TOKEN (TOKstring));
	  tokens.current.popFront();

	  // Copy string into token.
	  while (tokens.current[0] != '"')
	    {
	      switch (tokens.current[0])
		{
		case '\\':
		  // Increment to next character and add it as well.
		  token.str ~= tokens.current[0 .. 2];
		  tokens.current = tokens.current[2 .. $];
		  break;

		case '\n':
		case '\r':
		  token.str ~= "\\n";
		  tokens.current.popFront();
  		  tokens.linenum++;
		  break;

		default:
		  token.str ~= tokens.current[0];
		  tokens.current.popFront();
		  break;
		}
	    }

	  // Adjust the current source position.
	  tokens.current.popFront();
	  continue;
	}

      // Operators.
      switch (tokens.current[0])
	{
	  mixin (OPERATOR ('.', TOKdot));
	  mixin (OPERATOR ('+', TOKplus));
	  mixin (OPERATOR ('-', TOKminus));
	  mixin (OPERATOR ('*', TOKmult));
	  mixin (OPERATOR ('/', TOKdiv));
	  mixin (OPERATOR ('%', TOKpercent));
	  mixin (OPERATOR ('^', TOKhat));
	  mixin (OPERATOR (',', TOKcomma));
	  mixin (OPERATOR ('?', TOKquestion));
	  mixin (OPERATOR (':', TOKcolon));
	  mixin (OPERATOR ('&', TOKampand));
	  mixin (OPERATOR ('|', TOKpipe));
	  mixin (OPERATOR ('@', TOKat));

	  mixin (OPERATOR ('(', TOKlparen));
	  mixin (OPERATOR (')', TOKrparen));

	  mixin (OPERATOR ('[', TOKlbracket));
	  mixin (OPERATOR (']', TOKrbracket));

	  mixin (OPERATOR ('}', TOKendblock));

	  mixin (OPERATOR2 ('=', '=', TOKequal, TOKeq));
	  mixin (OPERATOR2 ('>', '=', TOKgt, TOKge));
	  mixin (OPERATOR2 ('!', '=', TOKexclamation, TOKne));

	  mixin (OPERATOR3 ('<', '=', '>', TOKlt, TOKle, TOKcompare));

	case '{':
	  tokens.current.popFront();
	  if (!tokens.tokens.empty())
	    {
	      Token *last = tokens.tokens.back();
	      if (last.type == TOKidentifier)
		{
		  last.type = TOKstartblock;
		  continue;
		}
	    }
	  mixin (TOKEN (TOKstartblock));
	  continue;


	case ';':
	  tokens.current.popFront();
	  // No repetative semicolons.
	  if (tokens.tokens.back().type != TOKsemicolon)
	    mixin (TOKEN (TOKsemicolon));
	  continue;
            
	case '\n':
	  tokens.linenum++;
	  tokens.current.popFront();
	  continue;

	case '#':
	  // Ignore comments.
	  while (tokens.current[0] != '\n')
	    tokens.current.popFront();
	  continue;

	default:
	  tokens.error = "Unrecognized syntax";
	  return tokens;
	}
    }

  mixin (TOKEN (TOKend));
  return tokens;
}


void printTokens (Tokens *tokens)
{
  foreach (tok; tokens.tokens)
    writefln("[%s]", printToken (tok));
}

string printToken(Token *tok)
{
  string PRINT()(TOK tok, string id)
  {
    return "case "~to!string(tok)~":"~
	   "  return \""~(id)~"\";";
  }

  switch (tok.type)
    {
      mixin (PRINT (TOKor, "or"));
      mixin (PRINT (TOKand, "and"));
      mixin (PRINT (TOKdel, "del"));
      mixin (PRINT (TOKsys, "sys"));
      mixin (PRINT (TOKtrap, "trap"));
      mixin (PRINT (TOKargs, "args"));
      mixin (PRINT (TOKarg, "arg"));
      mixin (PRINT (TOKthis, "this"));
      mixin (PRINT (TOKself, "self"));
      mixin (PRINT (TOKraise, "raise"));
      mixin (PRINT (TOKreturn, "return"));
      mixin (PRINT (TOKglobal, "global"));
      mixin (PRINT (TOKlexical, "lexical"));
      mixin (PRINT (TOKtrapped, "trapped"));
      mixin (PRINT (TOKsemicolon, ";"));
      mixin (PRINT (TOKdot, "."));
      mixin (PRINT (TOKplus, "+"));
      mixin (PRINT (TOKminus, "-"));
      mixin (PRINT (TOKmult, "*"));
      mixin (PRINT (TOKdiv, "/"));
      mixin (PRINT (TOKpercent, "%"));
      mixin (PRINT (TOKhat, "^"));
      mixin (PRINT (TOKcomma, ","));
      mixin (PRINT (TOKquestion, "?"));
      mixin (PRINT (TOKcolon, ":"));
      mixin (PRINT (TOKequal, "="));
      mixin (PRINT (TOKampand, "&"));
      mixin (PRINT (TOKpipe, "|"));
      mixin (PRINT (TOKat, "@"));
      mixin (PRINT (TOKeq, "=="));
      mixin (PRINT (TOKlt, "<"));
      mixin (PRINT (TOKle, "<="));
      mixin (PRINT (TOKgt, ">"));
      mixin (PRINT (TOKge, ">="));
      mixin (PRINT (TOKcompare, "<>"));
      mixin (PRINT (TOKexclamation, "!"));
      mixin (PRINT (TOKne, "!="));
      mixin (PRINT (TOKlparen, "("));
      mixin (PRINT (TOKrparen, ")"));
      mixin (PRINT (TOKlbracket, "["));
      mixin (PRINT (TOKrbracket, "]"));
      mixin (PRINT (TOKstartblock, "{"));
      mixin (PRINT (TOKendblock, "}"));
      mixin (PRINT (TOKend, "EOF"));

    case TOKidentifier:
      return tok.str;

    case TOKstring:
      return "\"" ~ tok.str ~ "\"";

    case TOKnumber:
      return to!string(tok.number);

    default:
      return "__error";
    }
}


