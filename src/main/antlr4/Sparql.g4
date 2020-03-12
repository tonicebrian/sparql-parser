grammar Sparql;

@parser::members {public static boolean allowsBlankNodes = true;}

statement: query | update
;

query: prologue (selectQuery | constructQuery | describeQuery | askQuery) valuesClause
;

prologue: (baseDecl | prefixDecl)*
;

baseDecl: 'BASE' IRIREF
;

prefixDecl: 'PREFIX' PNAME_NS IRIREF
;

selectQuery: selectClause datasetClause* whereClause solutionModifier;

subSelect: selectClause whereClause solutionModifier valuesClause;

selectClause: 'SELECT' ('DISTINCT' | 'REDUCED')? ((var | ('(' expression 'AS' var ')'))+ | '*');

constructQuery: 'CONSTRUCT' (constructTemplate datasetClause* whereClause solutionModifier | datasetClause* 'WHERE' '{' triplesTemplate? '}' solutionModifier);

describeQuery: 'DESCRIBE' (varOrIri+ | '*') datasetClause* whereClause? solutionModifier;

askQuery: 'ASK' datasetClause* whereClause solutionModifier;

datasetClause: 'FROM' (defaultGraphClause| namedGraphClause);

defaultGraphClause: sourceSelector;

namedGraphClause: 'NAMED' sourceSelector;

sourceSelector: iri;

whereClause: 'WHERE'? groupGraphPattern;

solutionModifier: groupClause? havingClause? orderClause? limitOffsetClauses?;

groupClause: 'GROUP' 'BY' groupCondition+;

groupCondition: builtInCall | functionCall | '(' expression ('AS' var)? ')' | var;

havingClause: 'HAVING' havingCondition+;

havingCondition: constraint;

orderClause: 'ORDER' 'BY' orderCondition+;

orderCondition: (('ASC' | 'DESC') brackettedExpression)
   | (constraint | var)
   ;

limitOffsetClauses: limitClause offsetClause? | offsetClause limitClause?;

limitClause: 'LIMIT' INTEGER;

offsetClause: 'OFFSET' INTEGER;

valuesClause: ('VALUES' dataBlock)?;

update: prologue (update1 (';' update)? )?;

update1: load | clear | drop | add | move | copy | create | insertData | deleteData | deleteWhere | modify ;

load: 'LOAD' 'SILENT'? iri ('INTO' graphRef)?
;

clear: 'CLEAR' 'SILENT'? graphRefAll;

drop: 'DROP' 'SILENT'? graphRefAll;

create: 'CREATE' 'SILENT'? graphRef;

add: 'ADD' 'SILENT'? graphOrDefault 'TO' graphOrDefault;

move: 'MOVE' 'SILENT'? graphOrDefault 'TO' graphOrDefault;

copy: 'COPY' 'SILENT'? graphOrDefault 'TO' graphOrDefault;

insertData
: 'INSERT DATA' quadData;

deleteData
@init {
allowsBlankNodes = false;
}
@after {
allowsBlankNodes = true;
}
: 'DELETE DATA' quadData;

deleteWhere
@init {
allowsBlankNodes = false;
}
@after {
allowsBlankNodes = true;
}
: 'DELETE WHERE' quadPattern;

modify: ('WITH' iri)? (deleteClause insertClause?| insertClause) usingClause* 'WHERE' groupGraphPattern;

deleteClause
@init {
allowsBlankNodes = false;
}
@after {
allowsBlankNodes = true;
}
: 'DELETE' quadPattern;

insertClause: 'INSERT' quadPattern;

usingClause: 'USING' (iri | 'NAMED' iri);

graphOrDefault: 'DEFAULT' | 'GRAPH'? iri;

graphRef: 'GRAPH' iri;

graphRefAll: graphRef | 'DEFAULT' | 'NAMED' | 'ALL';

quadPattern: '{' quads '}';

quadData: '{' quads '}';

quads: triplesTemplate? (quadsNotTriples '.'? triplesTemplate?) *
;

quadsNotTriples: 'GRAPH' varOrIri groupGraphPattern
;

triplesTemplate: triplesSameSubject ('.' triplesTemplate?)?
;

groupGraphPattern: '{' (subSelect | groupGraphPatternSub) '}'
;

groupGraphPatternSub: triplesBlock? (graphPatternNotTriples '.'? triplesBlock? )*
;

triplesBlock: triplesSameSubjectPath ( '.' triplesBlock?)?
;

graphPatternNotTriples: groupOrUnionGraphPattern | optionalGraphPattern | minusGraphPattern | graphGraphPattern
                        | serviceGraphPattern | filter | bind | inlineData
;

optionalGraphPattern: 'OPTIONAL' groupGraphPattern
;

graphGraphPattern: 'GRAPH' varOrIri groupGraphPattern
;

serviceGraphPattern: 'SERVICE' 'SILENT'? varOrIri groupGraphPattern
;

bind: 'BIND' '(' expression 'AS' var ')'
;

inlineData: 'VALUES' dataBlock
;

dataBlock: inlineDataOneVar | inlineDataFull
;

inlineDataOneVar: var '{' dataBlockValue* '}'
;

inlineDataFull: (NIL | '(' var* ')') '{' ( '(' dataBlockValue* ')' | NIL)* '}'
;

dataBlockValue: iri | rdfLiteral | numericLiteral | booleanLiteral | 'UNDEF'
;

minusGraphPattern: 'MINUS' groupGraphPattern
;

groupOrUnionGraphPattern: groupGraphPattern ('UNION' groupGraphPattern)*
;

filter: 'FILTER' constraint
;

constraint: brackettedExpression | builtInCall | functionCall
;

functionCall: iri argList
;

argList: NIL | '(' 'DISTINCT'? expression ( ',' expression)* ')'
;

expressionList: NIL | '(' expression ( ',' expression)* ')'
;

constructTemplate: '{' constructTriples? '}'
;

constructTriples: triplesSameSubject ( '.' constructTriples? )?
;

triplesSameSubject: varOrTerm propertyListNotEmpty | triplesNode propertyList
;

propertyList: propertyListNotEmpty?
;

propertyListNotEmpty: verb objectList (';' (verb objectList)?)*
;

verb:
   varOrIri
   | 'a'
   | 'A'  // See note at the beginning of the grammar
;

objectList: object (',' object)*
;

object: graphNode
;

triplesSameSubjectPath: varOrTerm propertyListPathNotEmpty | triplesNodePath propertyListPath
;

propertyListPath: propertyListPathNotEmpty?
;

propertyListPathNotEmpty: (verbPath | verbSimple) objectListPath ( ';' ((verbPath | verbSimple) objectList)?)*
;

verbPath: path
;

verbSimple: var
;

objectListPath: objectPath (',' objectPath)*
;

objectPath: graphNodePath
;

path: pathAlternative
;

pathAlternative: pathSequence ('|' pathSequence)*
;

pathSequence: pathEltOrInverse ('/' pathEltOrInverse)*
;

pathElt:  pathPrimary pathMod?
;

pathEltOrInverse:  pathElt | '^' pathElt
;

pathMod:  '?' | '*' | '+'
;

pathPrimary:
  iri
  | 'a'
  | 'A'  // See note at the beginning of the grammar
  | '!' pathNegatedPropertySet
  | '(' path ')'
;

pathNegatedPropertySet:  pathOneInPropertySet | '(' ( pathOneInPropertySet ( '|' pathOneInPropertySet )* )? ')'
;

pathOneInPropertySet:  iri
| 'a'
| 'A'   // See note at the beginning of the grammar
| '^' (
     iri
     | 'a'
     | 'A' // See note at the beginning of the grammar
     )
;

triplesNode:  collection | blankNodePropertyList
;

blankNodePropertyList:  '[' propertyListNotEmpty ']'
;

triplesNodePath:  collectionPath | blankNodePropertyListPath
;

blankNodePropertyListPath:  '[' propertyListPathNotEmpty ']'
;

collection:  '(' graphNode+ ')'
;

collectionPath:  '(' graphNodePath+ ')'
;

graphNode:  varOrTerm | triplesNode
;

graphNodePath:  varOrTerm | triplesNodePath
;

varOrTerm:  var | graphTerm
;

varOrIri:  var | iri
;

var:  VAR1 | VAR2
;

graphTerm:  iri | rdfLiteral | numericLiteral | booleanLiteral | {allowsBlankNodes}? blankNode | NIL
;

expression:  conditionalOrExpression
;

conditionalOrExpression:  conditionalAndExpression ( '||' conditionalAndExpression )*
;

conditionalAndExpression:  valueLogical ( '&&' valueLogical )*
;

valueLogical:  relationalExpression
;

relationalExpression:  numericExpression ( '=' numericExpression | '!=' numericExpression | '<' numericExpression | '>' numericExpression | '<=' numericExpression | '>=' numericExpression | 'IN' expressionList | 'NOT' 'IN' expressionList )?
;

numericExpression:  additiveExpression
;

additiveExpression:  multiplicativeExpression ( '+' multiplicativeExpression | '-' multiplicativeExpression | ( numericLiteralPositive | numericLiteralNegative ) ( ( '*' unaryExpression ) | ( '/' unaryExpression ) )* )*
;

multiplicativeExpression:  unaryExpression ( '*' unaryExpression | '/' unaryExpression )*
;

unaryExpression:    '!' primaryExpression
| '+' primaryExpression
| '-' primaryExpression
| primaryExpression
;

primaryExpression:  brackettedExpression | builtInCall | iriOrFunction | rdfLiteral | numericLiteral | booleanLiteral | var
;

brackettedExpression:  '(' expression ')'
;

builtInCall:    aggregate
| 'STR' '(' expression ')'
| 'LANG' '(' expression ')'
| 'LANGMATCHES' '(' expression ',' expression ')'
| 'DATATYPE' '(' expression ')'
| 'BOUND' '(' var ')'
| 'IRI' '(' expression ')'
| 'URI' '(' expression ')'
| 'BNODE' ( '(' expression ')' | NIL )
| 'RAND' NIL
| 'ABS' '(' expression ')'
| 'CEIL' '(' expression ')'
| 'FLOOR' '(' expression ')'
| 'ROUND' '(' expression ')'
| 'CONCAT' expressionList
| substringExpression
| 'STRLEN' '(' expression ')'
| strReplaceExpression
| 'UCASE' '(' expression ')'
| 'LCASE' '(' expression ')'
| 'ENCODE_FOR_URI' '(' expression ')'
| 'CONTAINS' '(' expression ',' expression ')'
| 'STRSTARTS' '(' expression ',' expression ')'
| 'STRENDS' '(' expression ',' expression ')'
| 'STRBEFORE' '(' expression ',' expression ')'
| 'STRAFTER' '(' expression ',' expression ')'
| 'YEAR' '(' expression ')'
| 'MONTH' '(' expression ')'
| 'DAY' '(' expression ')'
| 'HOURS' '(' expression ')'
| 'MINUTES' '(' expression ')'
| 'SECONDS' '(' expression ')'
| 'TIMEZONE' '(' expression ')'
| 'TZ' '(' expression ')'
| 'NOW' NIL
| 'UUID' NIL
| 'STRUUID' NIL
| 'MD5' '(' expression ')'
| 'SHA1' '(' expression ')'
| 'SHA256' '(' expression ')'
| 'SHA384' '(' expression ')'
| 'SHA512' '(' expression ')'
| 'COALESCE' expressionList
| 'IF' '(' expression ',' expression ',' expression ')'
| 'STRLANG' '(' expression ',' expression ')'
| 'STRDT' '(' expression ',' expression ')'
| 'SAMETERM' '(' expression ',' expression ')'
| 'ISIRI' '(' expression ')'
| 'ISURI' '(' expression ')'
| 'ISBLANK' '(' expression ')'
| 'ISLITERAL' '(' expression ')'
| 'ISNUMERIC' '(' expression ')'
| regexExpression
| existsFunc
| notExistsFunc
;

regexExpression:  'REGEX' '(' expression ',' expression ( ',' expression )? ')'
;

substringExpression:  'SUBSTR' '(' expression ',' expression ( ',' expression )? ')'
;

strReplaceExpression:  'REPLACE' '(' expression ',' expression ',' expression ( ',' expression )? ')'
;

existsFunc:  'EXISTS' groupGraphPattern
;

notExistsFunc:  'NOT' 'EXISTS' groupGraphPattern
;

aggregate:    'COUNT' '(' 'DISTINCT'? ( '*' | expression ) ')'
| 'SUM' '(' 'DISTINCT'? expression ')'
| 'MIN' '(' 'DISTINCT'? expression ')'
| 'MAX' '(' 'DISTINCT'? expression ')'
| 'AVG' '(' 'DISTINCT'? expression ')'
| 'SAMPLE' '(' 'DISTINCT'? expression ')'
| 'GROUP_CONCAT' '(' 'DISTINCT'? expression ( ';' 'SEPARATOR' '=' string )? ')'
;

iriOrFunction:  iri argList?
;

rdfLiteral:  string ( LANGTAG | ( '^^' iri ) )?
;

numericLiteral:  numericLiteralUnsigned | numericLiteralPositive | numericLiteralNegative
;

numericLiteralUnsigned:  INTEGER | DECIMAL | DOUBLE
;

numericLiteralPositive:  INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
;

numericLiteralNegative:  INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
;

booleanLiteral:
 'true'
 | 'false'
 | 'TRUE'     // See Note at the beginning of the grammar
 | 'FALSE'    // See Note at the beginning of the grammar
;

string:  STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2
;

iri:  IRIREF | prefixedName
;

prefixedName:  PNAME_LN | PNAME_NS
;

blankNode:  BLANK_NODE_LABEL | ANON
;


IRIREF:  '<' ( ~('<' | '>' | '"' | '{' | '}' | '|' | '^' | '\\' | '`') | (PN_CHARS))* '>'
;

PNAME_NS:  PN_PREFIX? ':'
;

PNAME_LN:  PNAME_NS PN_LOCAL
;

BLANK_NODE_LABEL:  '_:' ( PN_CHARS_U | [0-9] ) ((PN_CHARS|'.')* PN_CHARS)?
;

VAR1:  '?' VARNAME
;

VAR2:  '$' VARNAME
;

LANGTAG:  '@' [a-zA-Z]+ ('-' [a-zA-Z0-9]+)*
;

INTEGER:  [0-9]+
;

DECIMAL:  [0-9]* '.' [0-9]+
;

DOUBLE:  [0-9]+ '.' [0-9]* EXPONENT | '.' ([0-9])+ EXPONENT | ([0-9])+ EXPONENT
;

INTEGER_POSITIVE:  '+' INTEGER
;

DECIMAL_POSITIVE:  '+' DECIMAL
;

DOUBLE_POSITIVE:  '+' DOUBLE
;

INTEGER_NEGATIVE:  '-' INTEGER
;

DECIMAL_NEGATIVE:  '-' DECIMAL
;

DOUBLE_NEGATIVE:  '-' DOUBLE
;

EXPONENT:  [eE] [+-]? [0-9]+
;

STRING_LITERAL1:  '\'' ( ~('\u0027' | '\u005C' | '\u000A' | '\u000D') | ECHAR )* '\''
;

STRING_LITERAL2:  '"' ( ~('\u0022' | '\u005C' | '\u000A' | '\u000D') | ECHAR )* '"'
;

STRING_LITERAL_LONG1:  '\'\'\'' ( ( '\'' | '\'\'' )? ( [^'\\] | ECHAR ) )* '\'\'\''
;

STRING_LITERAL_LONG2:  '"""' ( ( '"' | '""' )? ( [^"\\] | ECHAR ) )* '"""'
;

ECHAR:  '\\' ('t' | 'b' | 'n' | 'r' | 'f' | '"' | '\'')
;

NIL:  '(' WS* ')'
;

WS:  (COMMENT | (' ' | '\t' | '\r' | '\n')+) -> skip
;

COMMENT: '#' ~('\u000A' | '\u000D')* ('\u000A' | '\u000D')
;

ANON:  '[' WS* ']'
;

PN_CHARS_BASE
  :  [A-Z]
  | [a-z]
  | [\u00C0-\u00D6]
  | [\u00D8-\u00F6]
  | [\u00F8-\u02FF]
  | [\u0370-\u037D]
  | [\u037F-\u1FFF]
  | [\u200C-\u200D]
  | [\u2070-\u218F]
  | [\u2C00-\u2FEF]
  | [\u3001-\uD7FF]
  | [\uF900-\uFDCF]
  | [\uFDF0-\uFFFD]
;

PN_CHARS_U:  PN_CHARS_BASE | '_'
;

VARNAME:  ( PN_CHARS_U | [0-9] ) ( PN_CHARS_U | [0-9] | '\u00B7' | [\u0300-\u036F] | [\u203F-\u2040] )*
;

PN_CHARS:  PN_CHARS_U | '-' | [0-9] | '\u00B7' | [\u0300-\u036F] | [\u203F-\u2040]
;

PN_PREFIX:  PN_CHARS_BASE ((PN_CHARS|'.')* PN_CHARS)?
;

PN_LOCAL:  (PN_CHARS_U | ':' | [0-9] | PLX ) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX) )?
;

PLX:  PERCENT | PN_LOCAL_ESC
;

PERCENT:  '%' HEX HEX
;

HEX:  [0-9] | [A-F] | [a-f]
;

PN_LOCAL_ESC:  '\\' ( ':' | '_' | '~' | '.' | '-' | '!' | '$' | '&' | '\'' | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%' )
;

