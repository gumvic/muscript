ast = _ statement:statement _ {
  return statement;
}

nl = [\n\r] / [\n]

_ "whitespace" = ([ \t\n\r] / comment)*
__ "whitespace" = ([ \t] / comment)*

oneLineComment = "#" (!nl .)*
multilineComment = "#{" (multilineComment / (!"}#" .))* "}#"
comment = multilineComment / oneLineComment

reservedWord "special word" =
  wordWildcard
  / wordCase
  / wordWhen
  / wordElse
  / wordMatch
  / wordDo
  / wordLet
  / wordFn
  / wordIn
  / wordEnd

wordWildcard "_" = "_" !beginNameChar
wordCase "case" = "case" !beginNameChar
wordWhen "when" = "when" !beginNameChar
wordElse "else" = "else" !beginNameChar
wordMatch "match" = "match" !beginNameChar
wordDo "do" = "do" !beginNameChar
wordLet "let" = "let" !beginNameChar
wordFn "fn" = "fn" !beginNameChar
wordIn "in" = "in" !beginNameChar
wordEnd "end" = "end" !beginNameChar

beginNameChar = [a-zA-Z_]
nameChar = [a-zA-Z_0-9]
name "name" =
  !reservedWord
  first:beginNameChar
  rest:(nameChar+)?
  {
    return {
      type: "name",
      name: [first].concat(rest || []).join(""),
      location: location()
    };
  }

reservedOperator = ("=" / "->") !operatorChar
operatorChar = [\+\-\*\/\>\<\=\%\!\|\&|\^|\~\?]
operator "operator" =
  !reservedOperator
  chars:operatorChar+ {
  return {
    type: "name",
    name: chars.join(""),
    location: location()
  };
}

skip "_" = wordWildcard {
  return {
    type: "skip",
    location: location()
  };
}

undefined "undefined" = "undefined" !beginNameChar {
  return {
    type: "undefined",
    location: location()
  };
}

null "null" = "null" !beginNameChar {
  return {
    type: "null",
    location: location()
  };
}

false "false" = "false" !beginNameChar {
  return {
    type: "false",
    location: location()
  };
}

true "true" = "true" !beginNameChar {
  return {
    type: "true",
    location: location()
  };
}

decimal_point = "."
digit1_9      = [1-9]
e             = [eE]
exp           = e (minus / plus)? DIGIT+
frac          = decimal_point DIGIT+
int           = zero / (digit1_9 DIGIT*)
minus         = "-"
plus          = "+"
zero          = "0"
number "number" = int frac? exp? {
  return {
    type: "number",
    value: text(),
    location: location()
  };
}

char
  = unescaped
  / escape
    sequence:(
        '"'
      / "\\"
      / "/"
      / "b" { return "\b"; }
      / "f" { return "\f"; }
      / "n" { return "\n"; }
      / "r" { return "\r"; }
      / "t" { return "\t"; }
      / "u" digits:$(HEXDIG HEXDIG HEXDIG HEXDIG) {
          return String.fromCharCode(parseInt(digits, 16));
        }
    )
    { return sequence; }
escape         = "\\"
quotation_mark = '"'
unescaped      = [\x20-\x21\x23-\x5B\x5D-\u10FFFF]
DIGIT  = [0-9]
HEXDIG = [0-9a-f]i
string "string" = quotation_mark chars:char* quotation_mark {
  return {
    type: "string",
    value: chars.join(""),
    location: location()
  };
}

listItem = expression

list "list" =
  "[" _
  items:(first:listItem rest:(_ "," _ item:listItem { return item; })* { return [first].concat(rest); })?
  _ "]" {
    return {
      type: "list",
      items: items || [],
      location: location()
    };
  }

mapKeyValueItem = key:expression _ ":" _ value:expression {
  return {
    key: key,
    value: value
  };
}

mapKeyItem = key:name {
  return {
    key: key,
    value: key
  };
}

mapItem = mapKeyValueItem / mapKeyItem

map "map" =
  "{" _
  items:(first:mapItem rest:(_ "," _ item:mapItem { return item; })* { return [first].concat(rest); })?
  _ "}" {
    return {
      type: "map",
      items: items || [],
      location: location()
    };
  }

funArgs =
  "(" _
  args:(first:name rest:(_ "," _ arg:name { return arg; })* { return [first].concat(rest); })? _
  _ ")" {
  return {
    args: args || [],
    location: location()
  };
}

function = args:funArgs _ "->" _ body:expression {
  return {
    args: args.args,
    body: body,
    text: text()
  };
}

lambdaFunction = wordFn _ fun:function {
  return {
    ...fun,
    type: "function",
    text: "fn" + fun.text,
    location: location()
  };
}

caseBranch = wordWhen _ condition:expression _ ":" _ value:expression {
  return {
    condition: condition,
    value: value
  };
}

caseOtherwise = wordElse _ otherwise:expression {
  return otherwise;
}

case "case" =
  wordCase _
  branches:(branch:caseBranch _ { return branch; })+
  otherwise:caseOtherwise _
  wordEnd {
  return {
    type: "case",
    branches: branches,
    otherwise: otherwise,
    location: location()
  };
}

matchBranch =
  wordWhen _
  patterns:(first:expression rest:(_ "," _ pattern:expression { return pattern; })* { return [first].concat(rest); })
  _ ":" _
  value:expression {
  return {
    patterns: patterns,
    value: value
  };
}

matchOtherwise = wordElse _ otherwise:expression {
  return otherwise;
}

match "match" =
  wordMatch _
  names:(first:name rest:(_ "," _ name:name { return name; })* { return [first].concat(rest); }) _
  branches:(branch:matchBranch _ { return branch; })+
  otherwise:matchOtherwise _
  wordEnd {
  for(let { patterns, location } of branches) {
    if (patterns.length !== names.length) {
      error("Wrong amount of patterns", patterns[0].location);
    }
  }
  return {
    type: "match",
    names: names,
    branches: branches,
    otherwise: otherwise,
    location: location()
  };
}

declarationDefinition = name:name _ ":" _ typeAST:expression {
  return {
    type: "definition",
    kind: "declaration",
    name: name,
    typeAST: typeAST,
    location: location()
  };
}

constantDefinition = name:name _ "=" _ value:expression {
  return {
    type: "definition",
    kind: "constant",
    name: name,
    value: value,
    location: location()
  };
}

functionDefinition = name:name _ fun:function {
  return {
    ...fun,
    type: "definition",
    kind: "function",
    name: name,
    location: location()
  };
}

definition = declarationDefinition / constantDefinition / functionDefinition

scope "let" =
  wordLet _
  definitions:(definition:definition _ { return definition; })+ _
  wordIn _
  body:expression _
  wordEnd {
  return {
    type: "scope",
    definitions: definitions,
    body: body,
    location: location()
  };
}

subExpression "sub-expression" = "(" _ expression:expression _ ")" {
  return expression;
}

atom =
  undefined
  / null
  / false
  / true
  / number
  / string
  / skip
  / name
  / list
  / map
  / lambdaFunction
  / case
  / match
  / scope
  / subExpression

unary = operator:operator __ operand:atom {
  return {
    type: "call",
    callee: operator,
    args: [operand],
    location: location()
  };
}

callee = unary / atom

callArgs = "(" _
  args:(first:expression rest:(_ "," _ arg:expression { return arg; })* { return [first].concat(rest); })?
_ ")" {
  return {
    args: args || [],
    location: location()
  };
}

call = callee:callee __ chain:(args:callArgs __ { return args; })+ {
  return chain.reduce((callee, args) => ({
    type: "call",
    callee: callee,
    args: args.args,
    location: args.location
  }), callee);
}

binaryOperand = call / callee

binary =
  first:binaryOperand
  rest:(__ operator:operator _ right:binaryOperand { return { operator, right }; })+ {
  return rest.reduce(
    (left, { operator, right }) => ({
      type: "call",
      callee: operator,
      args: [left, right],
      location: operator.location
    }),
    first);
  }

expression = binary / binaryOperand / operator

statement = definition / expression