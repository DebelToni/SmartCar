module Main where

import Data.List (nub, sort)
import Data.Maybe (fromMaybe)

-- | A data type representing a recursive binary tree with labeled nodes

data BinaryTree a = Leaf | Node a (BinaryTree a) (BinaryTree a) deriving (Show, Eq)

-- | Function to insert an element into the binary search tree

insert :: (Ord a) => a -> BinaryTree a -> BinaryTree a
insert x Leaf = Node x Leaf Leaf
insert x (Node y left right)
    | x < y     = Node y (insert x left) right
    | x > y     = Node y left (insert x right)
    | otherwise = Node y left right -- ignore duplicates

-- | Function to build a binary search tree from a list

buildTree :: (Ord a) => [a] -> BinaryTree a
buildTree = foldl (flip insert) Leaf

-- | Function to perform an in-order traversal of the tree

inOrderTraversal :: BinaryTree a -> [a]
inOrderTraversal Leaf = []
inOrderTraversal (Node x left right) = inOrderTraversal left ++ [x] ++ inOrderTraversal right

-- | Function to find the maximum depth of the tree

maxDepth :: BinaryTree a -> Int
maxDepth Leaf = 0
maxDepth (Node _ left right) = 1 + max (maxDepth left) (maxDepth right)

-- | Function to generate all root-to-leaf paths

generatePaths :: BinaryTree a -> [[a]]
generatePaths Leaf = [[]]
generatePaths (Node x Leaf Leaf) = [[x]]
generatePaths (Node x left right) =
    map (x:) (generatePaths left) ++ map (x:) (generatePaths right)

-- | Function to compute the sum of all node values in a numeric tree

sumTree :: Num a => BinaryTree a -> a
sumTree Leaf = 0
sumTree (Node x left right) = x + sumTree left + sumTree right

-- | Function to filter nodes based on a predicate

filterTree :: (a -> Bool) -> BinaryTree a -> BinaryTree a
filterTree _ Leaf = Leaf
filterTree p (Node x left right)
    | p x       = Node x (filterTree p left) (filterTree p right)
    | otherwise = mergeTrees (filterTree p left) (filterTree p right)

-- | Helper function to merge two trees

mergeTrees :: BinaryTree a -> BinaryTree a -> BinaryTree a
mergeTrees t1 Leaf = t1
mergeTrees Leaf t2 = t2
mergeTrees t1 t2 = t1 -- simplistic merge for demonstration

-- | Main function demonstrating usage

main :: IO ()
main = do
    let values = [10, 5, 15, 3, 7, 12, 18]
    let tree = buildTree values
    putStrLn "In-order traversal of the binary search tree:"
    print (inOrderTraversal tree)
    putStrLn $ "Maximum depth of the tree: " ++ show (maxDepth tree)
    putStrLn "All root-to-leaf paths:"
    print (generatePaths tree)
    putStrLn $ "Sum of all nodes: " ++ show (sumTree tree)
    let filteredTree = filterTree (> 10) tree
    putStrLn "Filtered tree with nodes > 10 (represented in-order):"
    print (inOrderTraversal filteredTree)
