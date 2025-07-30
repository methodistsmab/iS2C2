####################### CALCULATE PATHWAY SCORES #########################

#calculate activity score definition
calculate_activity_score_v2 <- function(graph_object,lambda){
  dataframe <- as_long_data_frame(graph_object)
  mean_corr <- mean(dataframe$weight[-1])
  # Lambda * (L-R * mean_corr) + (1-Lambda) * (Downstream genes * local corr)
  pas <- sum(c(lambda*(mean_corr*dataframe$from_weight[1]+mean_corr*dataframe$to_weight[1]),(1-lambda)*(dataframe$weight[-1] * dataframe$to_weight[-1]))) # weight=Edge_weight, to_weight=Vertex_weight
  if(is.na(pas)==TRUE){
    pas <- .Machine$double.xmin
  }
  return(pas)
}

#permutation test definition
permutation.graph.test_v2 <- function(receiver_all, collective_database, score, graph, kegg_df, n, lambda){
  set.seed(500)
  distribution <- c()
  distribution[1] <- score
  graph_dataframe_user <- as_long_data_frame(graph)
  collective_database_list <- split(collective_database, f = collective_database$Pathway_name)
  collective_index <- which(graph_dataframe_user[1,5] == names(collective_database_list))
  collective_pathway <- as.data.frame(collective_database_list[collective_index])
  pathway_genes <- c(collective_pathway[,1], collective_pathway[,2])
  user_pathway <- receiver_all[receiver_all$gene %in% pathway_genes,]
  names(user_pathway$Vertex_weight) <- seq_along(user_pathway$Vertex_weight)

  for(i in 2:n){
    random_from <- sample(receiver_all$avg_log2FC, size = nrow(graph_dataframe_user))
    random_to <- sample(receiver_all$avg_log2FC, size = nrow(graph_dataframe_user))
    perm_user <- transform(graph_dataframe_user, from_weight = random_from, to_weight = random_to)
    # perm_enrich_score <- sum(perm_user$from_weight[1], perm_user$Weight * perm_user$to_weight) # perm_user$Weight is a typo
    mean_corr <- mean(perm_user$weight[-1])
    perm_enrich_score <- sum(c(lambda*(mean_corr*perm_user$from_weight[1]+mean_corr*perm_user$to_weight[1]),(1-lambda)*(perm_user$weight[-1] * perm_user$to_weight[-1]))) # weight=Edge_weight, to_weight=Vertex_weight
    # perm_enrich_score <- sum(lambda*perm_user$from_weight[1],perm_user$weight * perm_user$to_weight)
    distribution[[i]] <- perm_enrich_score
  }
  distribution <- sort(distribution, decreasing = TRUE)
  dist_pos <- which(distribution == score)
  value <- (dist_pos/n)
  # If enrichment score is 0, we have distributions of zero and cannot find dist_pos
  if(length(dist_pos)>1){
    value <- mean(value)
  }
  return(value)
}

find_sig_of_pathway_branches_v2 <- function(graph_list,export_directory_path,collective_database, overall_dataframe, receiver_df, permutation_num=500, lambda=1){
  # dataframe_list <- split(overall_dataframe, f = overall_dataframe$Branch)
  d <- 1
  new_dataframe_list <- c()
  for(graph in graph_list){
    enrichment_score <- calculate_activity_score_v2(graph, lambda)
    subset_df <- as_long_data_frame(graph)
    subset_df$from <- subset_df$from_name
    subset_df$to <- subset_df$to_name
    subset_df$from_name <- NULL
    subset_df$to_name <- NULL
    p_val <- permutation.graph.test_v2(receiver_df, collective_database, enrichment_score, graph, subset_df, permutation_num, lambda)
    subset_df$p_val <- rep(p_val, nrow(subset_df))
    subset_df$PAS <- rep(enrichment_score, nrow(subset_df))
    new_dataframe_list[[d]] <- subset_df
    d <- d + 1
  }
  final_dataframe <- bind_rows(new_dataframe_list)
  final_dataframe <- final_dataframe[order(final_dataframe$p_val),]
  # # Only report pathways with p-val less than 0.05
  final_dataframe <- final_dataframe[final_dataframe$p_val < 0.05,]
  
  
  # Make individual folder for each pathway and save significant branches in each folder
  pathways <- unique(final_dataframe$Pathway_name)
  for (path in pathways){
    path_dir <- paste0(export_directory_path, "/", path)
    if (!dir.exists(path_dir)) {
      dir.create(path_dir)
    }
    temp_path <- final_dataframe[final_dataframe$Pathway_name == path,]
    write.table(temp_path, paste0(path_dir, "/",path,"_significant_branches.txt"), sep = '\t', quote = FALSE, row.names = FALSE)
  }
  return(final_dataframe)
}

###################### RESULTS FOUND #################################

