library(parallel)
library(foreach)
library(doParallel)

multithreaded_sort <- function(data, num_threads = detectCores()) {
  # Helper function: quicksort implementation
  quicksort <- function(vec) {
    if(length(vec) <= 1) {
      return(vec)
    } else {
      pivot <- vec[sample(length(vec), 1)]
      less_than <- vec[vec < pivot]
      equal_to <- vec[vec == pivot]
      greater_than <- vec[vec > pivot]
      return(c(quicksort(less_than), equal_to, quicksort(greater_than)))
    }
  }
  
  # Function to partition data into chunks
  partition_data <- function(data, n) {
    len <- length(data)
    sizes <- rep(floor(len / n), n)
    remainder <- len %% n
    if(remainder > 0) {
      sizes[1:remainder] <- sizes[1:remainder] + 1
    }
    indices <- cumsum(c(1, sizes))
    partitions <- mapply(function(start, end) data[start:end], indices[-length(indices)], indices[-1], SIMPLIFY = FALSE)
    return(partitions)
  }
  
  # Initialize parallel backend
  cl <- makeCluster(num_threads)
  registerDoParallel(cl)
  
  # Partition data
  partitions <- partition_data(data, num_threads)
  
  # Step 1: Sort each partition in parallel
  sorted_partitions <- foreach(part = partitions, .packages = 'base') %dopar% {
    quicksort(part)
  }
  
  # Function to merge two sorted vectors
  merge_two <- function(vec1, vec2) {
    i <- j <- 1
    result <- vector(mode = mode(vec1), length = length(vec1) + length(vec2))
    k <- 1
    while(i <= length(vec1) && j <= length(vec2)) {
      if(vec1[i] <= vec2[j]) {
        result[k] <- vec1[i]
        i <- i + 1
      } else {
        result[k] <- vec2[j]
        j <- j + 1
      }
      k <- k + 1
    }
    if(i <= length(vec1)) {
      result[k:(length(vec1)+length(vec2)-1)] <- vec1[i:length(vec1)]
    }
    if(j <= length(vec2)) {
      result[k:(length(vec1)+length(vec2)-1)] <- vec2[j:length(vec2)]
    }
    return(result)
  }
  
  # Step 2: Iteratively merge sorted partitions
  current_list <- sorted_partitions
  while(length(current_list) > 1) {
    next_list <- list()
    pairs <- length(current_list) %/% 2
    for(i in seq_len(pairs)) {
      merged <- merge_two(current_list[[2 * i - 1]], current_list[[2 * i]])
      next_list[[i]] <- merged
    }
    if(length(current_list) %% 2 == 1) {
      next_list[[length(next_list) + 1]] <- current_list[[length(current_list)]]
    }
    current_list <- next_list
  }
  
  # Stop the cluster
  stopCluster(cl)
  
  # Return sorted data
  return(current_list[[1]])
}

# Example usage:
# set.seed(123)
# unsorted_data <- sample(1:1e6, 1000000, replace = TRUE)
# sorted_data <- multithreaded_sort(unsorted_data, num_threads = 4)