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

module compiler.syntax;

import compiler.tokenizer;

import std.array;
import std.string;


static immutable TOK[][] token_syntax = [
    /* TOKor */		[						],
    /* TOKand */	[						],
    /* TOKdel */	[TOKidentifier					],
    /* TOKsys */	[TOKdot						],
    /* TOKtrap */	[TOKtrapped,	TOKsys,		TOKstartblock,
			 TOKstring,	TOKnumber			],
    /* TOKargs */	[TOKlbracket					],
    /* TOKarg */	[TOKidentifier					],
    /* TOKthis */	[TOKsemicolon,	TOKdot,		TOKplus,
			 TOKpercent,	TOKcomma,	TOKrparen,
			 TOKrbracket,	TOKendblock			],
    /* TOKself */	[TOKdot,	TOKlparen			],
    /* TOKraise */	[TOKstring					],
    /* TOKreturn */	[TOKsemicolon,	TOKcolon,	TOKlparen,
			 TOKidentifier,	TOKstring,	TOKnumber,
			 TOKargs,	TOKthis				],
    /* TOKglobal */	[TOKidentifier					],
    /* TOKlexical */	[TOKidentifier					],
    /* TOKtrapped */	[TOKsemicolon,	TOKcomma			],
    /* TOKsemicolon */	[TOKreturn,	TOKglobal,	TOKlexical,
			 TOKend,	TOKdel,		TOKampand,
			 TOKsys,	TOKexclamation,	TOKlparen,
			 TOKrparen,	TOKstartblock,	TOKendblock,
			 TOKidentifier,	TOKstring,	TOKnumber,
			 TOKarg,	TOKthis,	TOKself		],
    /* TOKdot */	[TOKidentifier					],
    /* TOKplus */	[TOKidentifier,	TOKstring,	TOKnumber,
			 TOKargs,	TOKthis,	TOKself		],
    /* TOKminus */	[TOKlparen,	TOKidentifier,	TOKnumber,
			 TOKargs,	TOKthis,	TOKself		],
    /* TOKmult */	[TOKidentifier,	TOKnumber,	TOKthis,
			 TOKself					],
    /* TOKdiv */	[TOKidentifier,	TOKnumber,	TOKthis,
			 TOKself					],
    /* TOKpercent */	[TOKidentifier,	TOKnumber,	TOKthis,
			 TOKself					],
    /* TOKhat */	[TOKidentifier,	TOKnumber,	TOKthis,
			 TOKself					],
    /* TOKcomma */	[TOKtrapped,	TOKsys,		TOKlbracket,
			 TOKstartblock,	TOKidentifier,	TOKstring,
			 TOKnumber,	TOKargs,	TOKarg,
			 TOKthis,	TOKself				],
    /* TOKquestion */	[TOKreturn,	TOKsys,		TOKlparen,
			 TOKidentifier, TOKstring,	TOKnumber,
			 TOKself					],
    /* TOKcolon */	[TOKreturn,	TOKsys,		TOKlparen,
			 TOKidentifier,	TOKstring,	TOKnumber,
			 TOKself					],
    /* TOKequal */	[TOKminus,	TOKampand,	TOKsys,
			 TOKlparen,	TOKlbracket,	TOKstartblock,
			 TOKidentifier,	TOKstring,	TOKnumber,
			 TOKargs,	TOKarg				],
    /* TOKampand */	[TOKlparen,	TOKlbracket,	TOKstartblock,
			 TOKidentifier,	TOKstring,	TOKnumber	],
    /* TOKpipe */	[TOKat,		TOKstartblock,			],
    /* TOKat */		[TOKdot						],
    /* TOKeq */		[TOKminus,	TOKampand,	TOKidentifier,
			 TOKnumber					],
    /* TOKlt */		[TOKminus,	TOKidentifier,	TOKnumber	],
    /* TOKle */		[TOKminus,	TOKnumber			],
    /* TOKgt */		[TOKminus,	TOKidentifier,	TOKnumber	],
    /* TOKge */		[TOKminus,	TOKidentifier,	TOKnumber	],
    /* TOKcompare */	[						],
    /* TOKexclamation */[TOKlparen,	TOKidentifier			],
    /* TOKne */		[TOKminus,	TOKnumber			],
    /* TOKlparen */	[TOKtrapped,	TOKminus,	TOKampand,
			 TOKsys,	TOKlparen,	TOKrparen,
			 TOKstartblock,	TOKidentifier,	TOKstring,
			 TOKnumber,	TOKargs,	TOKarg,
			 TOKthis					],
    /* TOKrparen */	[TOKsemicolon,	TOKdot,		TOKplus,
			 TOKminus,	TOKmult,	TOKdiv,
			 TOKcomma,	TOKquestion,	TOKcolon,
			 TOKeq,		TOKne,		TOKlparen,
			 TOKrparen,	TOKtrap,	TOKendblock,
			 TOKidentifier					],
    /* TOKlbracket */	[TOKthis,	TOKrbracket,	TOKidentifier,
			 TOKstring,	TOKnumber			],
    /* TOKrbracket */	[TOKsemicolon,	TOKdot,		TOKplus,
			 TOKminus,	TOKmult,	TOKcomma,
			 TOKquestion,	TOKequal,	TOKlparen,
			 TOKrparen,	TOKrbracket,	TOKtrap		],
    /* TOKstartblock */	[TOKreturn,	TOKlexical,	TOKsys,
			 TOKexclamation,TOKlparen,	TOKstartblock,
			 TOKendblock,	TOKidentifier,	TOKarg,
			 TOKthis,	TOKraise			],
    /* TOKendblock */	[TOKsemicolon,	TOKdot,		TOKcomma,
			 TOKpipe,	TOKlparen,	TOKrparen,
			 TOKtrap					],
    /* TOKidentifier */	[TOKsemicolon,	TOKdot,		TOKplus,
			 TOKminus,	TOKmult,	TOKdiv,
			 TOKpercent,	TOKhat,		TOKcomma,
			 TOKquestion,	TOKcolon,	TOKequal,
			 TOKeq,		TOKlt,		TOKle,
			 TOKgt,		TOKge,		TOKne,
			 TOKlparen,	TOKrparen,	TOKtrap,
			 TOKlbracket,	TOKrbracket			],
    /* TOKstring */	[TOKsemicolon,	TOKdot,		TOKplus,
			 TOKcomma,	TOKcolon,	TOKrparen,
			 TOKrbracket,	TOKendblock			],
    /* TOKnumber */	[TOKsemicolon,	TOKdot,		TOKplus,
			 TOKminus,	TOKmult,	TOKdiv,
			 TOKcomma,	TOKquestion,	TOKcolon,
			 TOKsys,	TOKrparen,	TOKrbracket,
			 TOKendblock					],
    /* TOKend */	[						],
];


string syntax_check(Tokens* tokens, Token* current)
{
  if (tokens.tokens.empty())
    return null;

  Token* last = tokens.tokens.back();
  immutable TOK[] toks = token_syntax[last.type];

  foreach (tok; toks)
    {
      if (tok == current.type)
	return null;
    }

  return format("Unrecognised syntax at line %s  (%s  %s)",
		tokens.linenum, printToken(last), printToken(current));
}


