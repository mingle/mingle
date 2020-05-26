# $Id: lalr.y,v 1.3 2005/11/20 13:29:32 aamine Exp $
#
# This is LALR grammer, and not LL/SLR.

class A
rule
  A : L '=' E

  L : i
    | R '^' i

  E : E '+' R
    | R
    | '@' L

  R : i
end
