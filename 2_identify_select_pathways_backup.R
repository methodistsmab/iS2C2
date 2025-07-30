suppressPackageStartupMessages({
library(igraph)
})

############### SELECT PATHWAYS THAT EXPRESS SOURCE LIGAND AND TARGET RECEPTOR ##################
find_preliminary_pathways <- function(ligand_receptor_dataframe, external_database){
  external_database_list <- split(external_database, f = external_database$Pathway_name)
  ligand_receptor_dataframe$Conc <- paste0(ligand_receptor_dataframe$Ligand, ligand_receptor_dataframe$Receptor)
  selected_pathways <- c()
  selected_pathways_names <- c()
  selected_ligand_receptors <- c()
  counter <- 1
  for(pathway in external_database_list){
    pathway <- pathway_one_directional(pathway)
    pathway <- pathway[!duplicated(pathway[c("From", "To")]),]
    find_pairs <- which(!is.na(match(pathway$Conc, ligand_receptor_dataframe$Conc)))
    if(length(find_pairs)==1){
      pairs <- pathway[find_pairs,]
      pathway_name <- pathway[1,5]
      selected_ligand_receptors[[counter]] <- list(as.character(pairs[1]), as.character(pairs[2]))
      selected_pathways[[counter]] <- pathway
      selected_pathways_names[[counter]] <- paste0(pathway_name, "_", as.character(pairs[1]), "_", as.character(pairs[2]))
      counter <- counter + 1
    }
    if(length(find_pairs) > 1){
      for(lr in find_pairs){
        pairs <- pathway[lr,]
        pathway_name <- pathway[1,5]
        selected_ligand_receptors[[counter]] <- list(as.character(pairs[1]), as.character(pairs[2]))
        selected_pathways[[counter]] <- pathway
        selected_pathways_names[[counter]] <- paste0(pathway_name, "_", as.character(pairs[1]), "_", as.character(pairs[2]))
        counter <- counter + 1
      }
    }
  }
  names(selected_pathways) <- selected_pathways_names
  names(selected_ligand_receptors) <- selected_pathways_names
  lr_pathway_list <- list(selected_pathways, selected_ligand_receptors)
  return(lr_pathway_list)
}


################ FIND SHORTEST BRANCHES FOR EACH SELECTED PATHWAY #################



find_activated_branches <- function(preliminary_ligand_receptors, receiver_df, intermediate_downstream_gene_num = 2, TF_targets = TF_targets){
  suppressWarnings({
    total_path_num <- 2 + intermediate_downstream_gene_num
    selected_ligands <- sapply(preliminary_ligand_receptors[2][[1]], "[[", 1)
    selected_receptors <- sapply(preliminary_ligand_receptors[2][[1]], "[[", 2)
    selected_pathways <- preliminary_ligand_receptors[[1]]
    shortest_paths_dataframe_leaf <- c()
    shortest_paths_dataframe_tf <- c()
    x <- 1
    i <- 1
    j <- 1
    for(database_pathway in selected_pathways){
      pathway_name <- names(database_pathway)
      vertices <- unique(c(database_pathway[,1], database_pathway[,2]))
      pathway_selected_graph <- graph_from_data_frame(d = database_pathway, vertices = vertices)
      pathway_selected_graph <- simplify(pathway_selected_graph)
      transcription_factors <- intersect(database_pathway[,2], TF_targets$TF)
      transcription_factors <- intersect(transcription_factors, receiver_df$gene)
      leaves_id <- V(pathway_selected_graph)[degree(pathway_selected_graph, mode = "out", loops = FALSE) == 0]
      leaves_name <- leaves_id$name
      leaves_name <- intersect(leaves_name, receiver_df$gene)
      for(leaf in leaves_name){
        pathway_branch_shortest_path_leaf <- get.shortest.paths(pathway_selected_graph, from = selected_receptors[x], to = leaf)
        if(length(names(pathway_branch_shortest_path_leaf$vpath[[1]])) > total_path_num){
          pathway <- names(pathway_branch_shortest_path_leaf$vpath[[1]])
          ligand_receptor <- database_pathway[database_pathway$From == selected_ligands[x] & database_pathway$To == pathway[1],]
          database_combined <- ligand_receptor
          for (idx in 1:length(pathway)-1){
            signal <- database_pathway[database_pathway$From == pathway[idx] & database_pathway$To == pathway[idx+1],]
            database_combined <- rbind(database_combined, signal) 
          }

          database_combined$Branch <- paste0("Leaf_branch_", as.character(i))
          pathway_branch <- paste0(pathway, collapse = "___")
          database_combined$Branch_path <- paste0(selected_ligands[x], "___", pathway_branch)
          database_combined$Signaling_protein <- c("Ligand", "Receptor", rep("Signaling", nrow(database_combined)-3), "Leaf")
          # add in the global sign variable
          global_sign <- c()
          tmp_sign <- 1.0
          receiver_avg_log2FC <- c()
          for (row in 1:nrow(database_combined)){
            tmp_sign <- sign(tmp_sign * database_combined$DB_edge_correlation[row])
            global_sign <- c(global_sign,tmp_sign)
            if (length(which(receiver_df$gene == database_combined$To[row]) != 0)){
              log2fc <- receiver_df$avg_log2FC[which(receiver_df$gene == database_combined$To[row])]
            } else {
              log2fc <- 0
            }
            receiver_avg_log2FC <- c(receiver_avg_log2FC, log2fc)
          }
          database_combined$Global_sign <- global_sign
          database_combined$receiver_avg_log2FC <- receiver_avg_log2FC
          # concatenate them into the overall dataframe
          shortest_paths_dataframe_leaf[[i]] <- database_combined
          i = i + 1
        }
      }
      for(factor in transcription_factors){
        pathway_branch_shortest_path_tf <- get.shortest.paths(pathway_selected_graph, from = selected_receptors[x], to = factor)
        if(length(names(pathway_branch_shortest_path_tf$vpath[[1]])) > total_path_num){
          pathway <- names(pathway_branch_shortest_path_tf$vpath[[1]])
          
          
          ligand_receptor <- database_pathway[database_pathway$From == selected_ligands[x] & database_pathway$To == pathway[1],]
          database_combined <- ligand_receptor
          for (idx in 1:length(pathway)-1){
            signal <- database_pathway[database_pathway$From == pathway[idx] & database_pathway$To == pathway[idx+1],]
            database_combined <- rbind(database_combined, signal) 
          }
          database_combined$Branch <- paste0("TF_branch_", as.character(i))
          pathway <- paste0(pathway, collapse = "___")
          database_combined$Branch_path <- paste0(selected_ligands[x], "___", pathway)
          database_combined$Signaling_protein <- c("Ligand", "Receptor", rep("Signaling", nrow(database_combined)-3), "TF")
          # add in the global sign variable
          global_sign <- c()
          tmp_sign <- 1.0
          receiver_avg_log2FC <- c()
          for (row in 1:nrow(database_combined)){
            tmp_sign <- sign(tmp_sign * database_combined$DB_edge_correlation[row])
            global_sign <- c(global_sign,tmp_sign)
            if (length(which(receiver_df$gene == database_combined$To[row]) != 0)){
              log2fc <- receiver_df$avg_log2FC[which(receiver_df$gene == database_combined$To[row])]
            } else {
              log2fc <- 0
            }
            receiver_avg_log2FC <- c(receiver_avg_log2FC, log2fc)
          }
          database_combined$Global_sign <- global_sign
          database_combined$receiver_avg_log2FC <- receiver_avg_log2FC
          # concatenate them into the overall dataframe
          shortest_paths_dataframe_tf[[j]] <- database_combined
          j = j + 1
        }
      }
      x <- x + 1
    }
    if(is.null(shortest_paths_dataframe_tf) == TRUE & is.null(shortest_paths_dataframe_leaf) == TRUE){
      shortest_paths_overall <- "no identified downstream targets found"
    }
    if(is.null(shortest_paths_dataframe_leaf) == TRUE & is.null(shortest_paths_dataframe_tf) == FALSE){
      shortest_paths_overall <- do.call("rbind", shortest_paths_dataframe_tf)
    }
    if(is.null(shortest_paths_dataframe_tf) == TRUE & is.null(shortest_paths_dataframe_leaf) == FALSE){
      shortest_paths_overall <- do.call("rbind", shortest_paths_dataframe_leaf)
    }
    if(is.null(shortest_paths_dataframe_leaf) == FALSE & is.null(shortest_paths_dataframe_tf) == FALSE){
      shortest_paths_dataframe_leaf <- do.call("rbind", shortest_paths_dataframe_leaf)
      shortest_paths_dataframe_tf <- do.call("rbind", shortest_paths_dataframe_tf)
      shortest_paths_overall <- rbind(shortest_paths_dataframe_leaf, shortest_paths_dataframe_tf)
    }
    return(shortest_paths_overall)
  })
}
