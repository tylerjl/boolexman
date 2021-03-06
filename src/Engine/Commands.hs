{- boolexman -- boolean expression manipulator
Copyright (c) 2018 Mert Bora ALPER <bora@boramalper.org>

Permission to use, copy, modify, and/or distribute this software for any purpose
with or without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.
-}
module Engine.Commands where

import Data.List (nub, delete, sort, (\\))
import Data.Maybe (isJust)

import DataTypes
import Engine.Transformers
import Engine.Other
import Utils (cartesianProduct)

subexpressions :: Expr -> SubexpressionsResult
subexpressions expr = let set = recurse expr
                      in SubexpressionsResult { set  = set
                                              , list = flattenSET set
                                              }
    where
        recurse :: Expr -> SET
        recurse e@(Enot se) = SET e [recurse se]
        recurse e@(Eimp cond cons) = SET e [recurse cond, recurse cons]
        recurse e@(Eite cond cons alt) = SET e [recurse cond, recurse cons, recurse alt]
        recurse e@(Eand ses) = SET e $ map recurse ses
        recurse e@(Eor ses)  = SET e $ map recurse ses
        recurse e@(Exor ses) = SET e $ map recurse ses
        recurse e@(Eiff ses) = SET e $ map recurse ses
        recurse e@(Esym _) = SET e []
        recurse Etrue  = SET Etrue []
        recurse Efalse = SET Efalse []

        flattenSET :: SET -> [Expr]
        flattenSET (SET expr sets) = sort $ nub $ expr : concatMap flattenSET sets

symbols :: Expr -> [Expr]
symbols = symbols'

tabulate :: Expr -> ([Expr], [[Bool]])
tabulate expr =
    let subexprs = sort $ list $ subexpressions expr
        evals    = sort $ map (\(ts, fs) -> map (evalS ts fs) subexprs) $ evaluations expr
    in (subexprs, evals)

toXNF :: Expr -> [([(Expr, Expr)], Expr)]
toXNF expr =
    let
    -- 0. Eliminate all if-then-else (ITE) subexpressions
        (eITE, pITE) = (nub $ eliminationsITE        expr,  normalise $ eliminateAllITE    expr)
    -- 1. Eliminate all if-and-only-if (IFF) subexpressions
        (eIFF, pIFF) = (nub $ eliminationsIFF        pITE,  normalise $ eliminateAllIFF    pITE)
    -- 2. Eliminate all implies (IMP) subexpressions
        (eIMP, pIMP) = (nub $ eliminationsIMP        pIFF,  normalise $ eliminateAllIMP    pIFF)
    -- 3. Eliminate all exclusive-org XOR subexpressions
        (eDNF, pDNF) = (nub $ eliminationsXORcnf     pIMP,  normalise $ eliminateAllXORcnf pIMP)
    -- 4. Distribute NOTs
        (dNOT, pNOT) = (nub $ distributionsNOT       pDNF,  normalise $ distributeAllNOT   pDNF)
    in
        [(eITE, pITE), (eIFF, pIFF), (eIMP, pIMP), (eDNF, pDNF), (dNOT, pNOT)]

{- toCNF, given an expression E, returns a list of ALWAYS EIGHT tuples whose
first element is (another list of tuples whose first element is the
subexpression before the predefined transformation and whose second element is
the self-same subexpression after the transformation), and whose second element
is resultant expression E' that is equivalent to E.
-}
toCNF :: Expr -> [([(Expr, Expr)], Expr)]
toCNF expr =
    let xnf          = toXNF expr
        (_, pNOT) = last xnf
    in  xnf
        -- 5. Distribute ORs over ANDs
        ++ [(nub $ distributionsOR pNOT, normalise $ distributeAllOR pNOT)]

{- toDNF, given an expression E, returns a list of ALWAYS EIGHT tuples whose
first element is (another list of tuples whose first element is the
subexpression before the predefined transformation and whose second element is
the self-same subexpression after the transformation), and whose second element
is resultant expression E' that is equivalent to E.
-}
toDNF :: Expr -> [([(Expr, Expr)], Expr)]
toDNF expr =
    let xnf          = toXNF expr
        (_, pNOT) = last xnf
    in  xnf
        -- 5. Distribute ORs over ANDs
        ++ [(nub $ distributionsAND pNOT, normalise $ distributeAllAND pNOT)]

{- eval, given a list of true symbols, false symbols, and an expression, returns
a tuple where the first element of the tuple is a another tuple of list of
expressions for the symbols in trueSymbols list and falseSymbols lists
(respectively) that do NOT exist in the expression supplied, and the second
element of the returned tuple is another tuple whose first element is the
partially-evaluated expression after the CNF-based elimination, second element
is the final result of partial evaluation in DNF form.

eval supports partial evaluation.
-}
eval :: [Expr] -> [Expr] -> Expr -> EvalResult
eval trueSymbols falseSymbols expr =
    let cnf = snd $ last $ toCNF expr
        pos = clausalForm cnf  -- product of sums
        pTE = evalCNF trueSymbols falseSymbols pos
        dnf =  snd $ last $ toDNF pTE
        sop = clausalForm dnf  -- sum of products
    in  EvalResult { redundantTrueSymbols  = filter (`notElem` symbols expr) trueSymbols
                   , redundantFalseSymbols = filter (`notElem` symbols expr) falseSymbols
                   , productOfSums         = pos
                   , trueEliminations      = evaluationsCNF trueSymbols falseSymbols pos
                   , postTrueElimination   = clausalForm pTE
                   , sumOfProducts         = sop
                   , falseEliminations     = evaluationsDNF trueSymbols falseSymbols sop
                   , postFalseElimination  = clausalForm $ evalDNF trueSymbols falseSymbols sop
                   , result                = evalDNF trueSymbols falseSymbols sop
                   }

-- RANDOM EXAMPLES
--   entail (A v B v C ^ D) (A ^ B ^ C => (E => (D => (Z => E))))
entail :: Expr -> Expr -> EntailmentResult
entail cond expr
    | all (not . (`subexprOf` cond)) [Etrue, Efalse] && all (not . (`subexprOf` expr)) [Etrue, Efalse] =
    let condPostITEelimination = eliminateAllITE    cond
        condPostIFFelimination = eliminateAllIFF    condPostITEelimination
        condPostXORelimination = eliminateAllXORcnf condPostIFFelimination
        exprPostITEelimination = eliminateAllITE    expr
        exprPostIFFelimination = eliminateAllIFF    exprPostITEelimination
        exprPostXORelimination = eliminateAllXORcnf exprPostIFFelimination
    in  EntailmentResult { condITEeliminations    = eliminationsITE    cond
                         , condPostITEelimination = condPostITEelimination
                         , condIFFeliminations    = eliminationsIFF    condPostITEelimination
                         , condPostIFFelimination = condPostIFFelimination
                         , condXOReliminations    = eliminationsXORcnf condPostIFFelimination
                         , condPostXORelimination = condPostXORelimination
                         , exprITEeliminations    = eliminationsITE    expr
                         , exprPostITEelimination = exprPostITEelimination
                         , exprIFFeliminations    = eliminationsIFF    exprPostITEelimination
                         , exprPostIFFelimination = exprPostIFFelimination
                         , exprXOReliminations    = eliminationsXORcnf exprPostIFFelimination
                         , exprPostXORelimination = exprPostXORelimination
                         , entailment             = recurse [condPostXORelimination] [exprPostXORelimination]
        }
    | otherwise = error "True and/or False has no place in an entailment!"
    where
        takeOne :: Show a => (a -> Bool) -> [a] -> a
        takeOne f l = head [x | x <- l, f x]

        recurse :: [Expr] -> [Expr] -> Entailment
        recurse conds exprs
            | any (`elem` conds) exprs = I $ Line conds exprs
            | any isAND conds = let s@(Eand andSubexprs) = takeOne isAND conds
                                in  Land (Line conds exprs) $ recurse (nub $ delete s conds ++ andSubexprs) exprs
            | any isOR  exprs = let s@(Eor orSubexprs) = takeOne isOR exprs
                                in  Ror (Line conds exprs) $ recurse conds (nub $ delete s exprs ++ orSubexprs)
            | any isOR  conds = let s@(Eor orSubexprs) = takeOne isOR conds
                                    conds' = delete s conds
                                in  Lor (Line conds exprs) $ nub $ map (\ose -> recurse (ose:conds') exprs) orSubexprs
            | any isAND exprs = let s@(Eand andSubexprs) = takeOne isAND exprs
                                    exprs' = delete s exprs
                                in  Rand (Line conds exprs) $ nub $ map (\ase -> recurse conds (ase:exprs')) andSubexprs
            | any isIMP conds = let s@(Eimp cond cons) = takeOne isIMP conds
                                    conds' = delete s conds
                                in  Limp (Line conds exprs) (recurse conds' (cond:exprs)) (recurse (cons:conds') exprs)
            | any isIMP exprs = let s@(Eimp cond cons) = takeOne isIMP exprs
                                    exprs' = delete s exprs
                                in  Rimp (Line conds exprs) $ recurse (nub $ cond:conds) (nub $ cons:exprs')
            | any isNOT conds = let s@(Enot subexpr) = takeOne isNOT conds
                                in  Lnot (Line conds exprs) $ recurse (delete s conds) (nub $ subexpr:exprs)
            | any isNOT exprs = let s@(Enot subexpr) = takeOne isNOT exprs
                                in  Rnot (Line conds exprs) $ recurse (nub $ subexpr:conds) (delete s exprs)
            | otherwise       = F (Line conds exprs)

{-
EXAMPLES:
  https://www.inf.ed.ac.uk/teaching/courses/inf1/cl/tutorials/2017/solutions4.pdf

  resolve ((A or B or not D) and (!A or D or E) and (!A or !C or E) and (B or C or E) and (!B or D or !E))
  resolve ((A v B v !D) ^ (!A v D v E) ^ (!A v !C v E) ^ (B v C v E) ^ (!B v D v !E))
  resolve ((A v B) ^ (A v !B v !C) ^ (!A v D) ^ (!B v C v D) ^ (!B v !D) ^ (!A v B v !D))
-}
resolve :: Expr -> Resolution
resolve expr = let initialStep = clausalForm $ snd $ last $ toCNF expr
                   (resolutionSteps, clauseStatuses) = recurse initialStep
               in  Resolution { initialStep     = initialStep
                              , resolutionSteps = resolutionSteps
                              , clauseStatuses  = clauseStatuses
                              }
    where
        recurse :: [Clause] -> (ResolutionSteps, ClauseStatuses)
        recurse clauses
            | isJust (findSuitableResolvent clauses) =
                let (Just resolvent)  = findSuitableResolvent clauses
                    usedClauses       = filter (\clause -> resolvent `elem` clause || Enot resolvent `elem` clause) clauses
                    newClauses        = nub $ calcNewClauses resolvent clauses
                    strikenClauses    = filter shouldStrike newClauses
                    dict              = map (\c -> (c, ResolvedBy resolvent)) usedClauses <++> map (\c -> (c, Striken)) strikenClauses
                    (nextRL, nextCD) = recurse $ (clauses \\ usedClauses) ++ (newClauses \\ strikenClauses)
                in  ((resolvent, newClauses) : nextRL, dict <++> nextCD)
           | otherwise = ([], [])

        calcNewClauses :: Resolvent -> [Clause] -> [Clause]
        calcNewClauses resolvent clauses = let positiveClauses = filter (\c ->      resolvent `elem` c) clauses
                                               negativeClauses = filter (\c -> Enot resolvent `elem` c) clauses
                                           in  map (uncurry $ merge resolvent) $ cartesianProduct positiveClauses negativeClauses

        merge :: Resolvent -> Clause -> Clause -> Clause
        merge resolvent positive negative = nub $ (resolvent `delete` positive) ++ (Enot resolvent `delete` negative)

        findSuitableResolvent :: [Clause] -> Maybe Expr
        findSuitableResolvent clauses = let symbols = nub $ concat clauses
                                            res     = filter (\sym -> any (sym `elem`) clauses && any (Enot sym `elem`) clauses) symbols
                                        in  if   not $ null res
                                            then Just $ head res
                                            else Nothing

        shouldStrike :: Clause -> Bool
        shouldStrike exprs = any (\expr -> Enot expr `elem` exprs) exprs
