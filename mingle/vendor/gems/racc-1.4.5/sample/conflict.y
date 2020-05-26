# $Id: conflict.y,v 1.3 2005/11/20 13:29:32 aamine Exp $
#
# Example of conflicted grammer.
# This grammer contains 1 Shift/Reduce conflict and 1 Reduce/Reduce conflict.

class A
rule
  target : outer

  outer  :
         | outer inner

  inner  :
         | inner ITEM
end
