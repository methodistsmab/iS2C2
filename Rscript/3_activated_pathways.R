suppressPackageStartupMessages({
library(igraph)
})


############### SPEARMAN CORRELATION TEST FUNCTION FOR USER INPUT  ##################

find_local_spearman_correlation <- function(receiver_counts, source_gene, target_gene, target_cell, exp_matrix_slot){
  if(source_gene %in% rownames(receiver_counts) & target_gene %in% rownames(receiver_counts)){
    correlation_test <- cor.test(x = receiver_counts[rownames(receiver_counts)==source_gene,], 
                                 y = receiver_counts[rownames(receiver_counts)==target_gene,], method = "spearman")
    correlation_score <- as.numeric(correlation_test[4])
    if(is.na(correlation_score)==TRUE){
      correlation_score <- .Machine$double.xmin
    }
  } else {
    correlation_score <- .Machine$double.xmin
  }
  return(correlation_score)
}

find_global_spearman_correlation <- function(target_gene, source_ligand, seurat_object, sender_counts, receiver_counts, sender_cell, target_cell, exp_matrix_slot){
  suppressWarnings({
    if(source_ligand %in% rownames(sender_counts) & target_gene %in% rownames(receiver_counts)){ #change ec.matrix to sender_counts and then receiver_counts
      correlation_test <- cor.test(x = sender_counts[rownames(sender_counts)==source_ligand,], #change ec.matrix to sender_counts
                                   y = receiver_counts[rownames(receiver_counts)==target_gene,], method = "spearman", exact = FALSE) #change ec.matrix to receiver_counts
      correlation_score <- as.numeric(correlation_test[4])
      if(is.na(correlation_test[4])==TRUE){
        correlation_test <- cor.test(x = c(sender_counts[rownames(sender_counts)==source_ligand,],0), #change ec.matrix to sender_counts
                                     y = c(receiver_counts[rownames(receiver_counts)==target_gene,],0), method = "spearman", exact = FALSE) #change ec.matrix to receiver_counts
        correlation_score <- as.numeric(correlation_test[4])
      }
      if(is.na(correlation_score)==TRUE){
        correlation_score <- .Machine$double.xmin
      }
    } else {
      correlation_score <- .Machine$double.xmin
    }
    return(correlation_score)
  })
}



################### CONSTRUCT WEIGHTED BRANCHES ########################

#function definition for building weighted graphs
construct_weighted_graph <- function(seurat_object, sender_cell, target_cell, exp_matrix_slot, database_df, sender_df, receiver_df, global_or_local="global"){
  suppressWarnings({
    branch_graphs_list <- c()
    i <- 1
    database_df <- as.data.frame(database_df)
    sender_df <- as.data.frame(sender_df)
    receiver_df <- as.data.frame(receiver_df)
    pathway_df_list <- split(database_df, f = database_df$Branch)
    progress_bar <- txtProgressBar(min = 0, max = length(pathway_df_list), initial = 0, char = "+", width = 100)
    sender_seurat <- subset(seurat_object, idents = sender_cell)
    receiver_seurat <- subset(seurat_object, idents = target_cell)
    sender_counts <- GetAssayData(sender_seurat, slot = exp_matrix_slot)
    receiver_counts <- GetAssayData(receiver_seurat, slot = exp_matrix_slot)
    rm(sender_seurat)
    rm(receiver_seurat)
    
    # 添加安全检查
    if(ncol(sender_counts) == 0 || ncol(receiver_counts) == 0) {
      warning("Sender or receiver counts matrix is empty")
      return(list(branch_graphs_list, list()))
    }
    
    # 安全的列数调整
    if(ncol(sender_counts) > ncol(receiver_counts)){
      if(ncol(receiver_counts) > 0) {
        sender_counts <- sender_counts[,1:ncol(receiver_counts), drop=FALSE]
      }
    } else {
      if(ncol(sender_counts) > 0) {
        receiver_counts <- receiver_counts[,1:ncol(sender_counts), drop=FALSE]
      }
    }
    
    # 再次检查调整后的矩阵
    if(ncol(sender_counts) == 0 || ncol(receiver_counts) == 0) {
      warning("After adjustment, sender or receiver counts matrix is empty")
      return(list(branch_graphs_list, list()))
    }
    
    new_pathway_df_list <- c()
    for(pathway_df in pathway_df_list){
      if(global_or_local == "global"){
        correlation_scores <- sapply(pathway_df[,2], find_global_spearman_correlation, source_ligand = pathway_df[1,1], seurat_object = seurat_object, sender_counts=sender_counts, receiver_counts=receiver_counts, sender_cell = sender_cell, target_cell = target_cell, exp_matrix_slot = exp_matrix_slot)
      }
      if(global_or_local == "local"){
        correlation_scores <- c()
        for(row in 1:nrow(pathway_df)){
         source_gene <- as.character(pathway_df[row,1])
         target_gene <- as.character(pathway_df[row,2])
         score <- find_local_spearman_correlation(receiver_counts = receiver_counts, source_gene = source_gene, target_gene = target_gene, target_cell = target_cell, exp_matrix_slot = exp_matrix_slot)
         correlation_scores[row]=score
        }
      }
      # # removed sign from the correlation score
      # pathway_df$Edge_weight <- pathway_df$DB_edge_correlation * correlation_scores
      if (global_or_local == "global"){
        pathway_df$Edge_weight <- abs(pathway_df$DB_edge_correlation) * pathway_df$Global_sign * abs(correlation_scores)
      } else {
        pathway_df$Edge_weight <- pathway_df$DB_edge_correlation * abs(correlation_scores)
      }
      
      ligand <- as.character(pathway_df[1,1])
      # vertices <- unique(c(pathway_df[1,1], pathway_df[,2]))
      vertices <- unique(c(pathway_df[,1], pathway_df[,2]))
      pathway <- pathway_df[-1,]
      pathway_ids <- unique(c(pathway[,1], pathway[,2]))
      user_pathway <- receiver_df[(toupper(receiver_df$gene)) %in% pathway_ids,]
      ligand_row <- sender_df[sender_df$gene == ligand,]
      overall <- rbind(ligand_row, user_pathway)
      overall$logFC_color <- ifelse(overall$avg_log2FC == 0, "Grey", 
                                    ifelse(overall$avg_log2FC > 0, "Red", "Blue"))
      pathway_branch_order <- str_split(pathway_df[1,]$Branch_path, "___")
      overall <- overall[match(pathway_branch_order[[1]], overall$gene),]
      overall <- overall[!duplicated(overall$gene),] # remove any duplicates
      if(length(c(pathway_ids, ligand)) == nrow(overall)){
        branch_graph <- graph_from_data_frame(pathway_df, vertices = vertices, directed = TRUE)
        # V(branch_graph)$weight <- c(overall[1,]$Vertex_weight, overall[-1,]$Vertex_weight * pathway_df$Edge_weight)
        V(branch_graph)$weight <- c(overall[1,]$Vertex_weight, overall[-1,]$Vertex_weight) # Removed the effect of edge weight
        V(branch_graph)$logFC <- overall$avg_log2FC
        V(branch_graph)$color <- overall$logFC_color
        E(branch_graph)$weight <- pathway_df$Edge_weight
        E(branch_graph)$color <- pathway_df$DB_edge_color
        branch_graphs_list[[i]] <- branch_graph
        new_pathway_df_list[[i]] <- pathway_df
        i <- i + 1
      }
      setTxtProgressBar(progress_bar, i)
    }
    close(progress_bar)
    return(list(branch_graphs_list,new_pathway_df_list))
  })
}


#function definition for building weighted graphs
construct_weighted_graph_ST <- function(seurat_object, sender_cell, target_cell, exp_matrix_slot, database_df, sender_df, receiver_df, global_or_local="global"){
  suppressWarnings({
    branch_graphs_list <- c()
    i <- 1
    database_df <- as.data.frame(database_df)
    sender_df <- as.data.frame(sender_df)
    receiver_df <- as.data.frame(receiver_df)
    pathway_df_list <- split(database_df, f = database_df$Branch)
    progress_bar <- txtProgressBar(min = 0, max = length(pathway_df_list), initial = 0, char = "+", width = 100)
    sender_seurat <- subset(seurat_object, idents = sender_cell)
    receiver_seurat <- subset(seurat_object, idents = target_cell)
    sender_counts <- GetAssayData(sender_seurat, slot = exp_matrix_slot)
    receiver_counts <- GetAssayData(receiver_seurat, slot = exp_matrix_slot)
    
    ### Convert to human genes if the seurat object is in mouse gene reference: sender_counts
    tryCatch({
      lookup <- homologene::mouse2human(rownames(sender_counts), db = homologene::homologeneData2)
      new_rownames <- lookup$humanGene[match(rownames(sender_counts), lookup$mouseGene)]
      
      # Check if new_rownames is valid and has the expected length
      if (length(new_rownames) == length(rownames(sender_counts))) {
        for (newr in 1:length(new_rownames)){
          if (is.na(new_rownames[newr]) || is.null(new_rownames[newr]) || new_rownames[newr] == ""){
            new_rownames[newr] <- toupper(rownames(sender_counts)[newr])
          }
        }
        rownames(sender_counts) <- new_rownames
        sender_counts <- sender_counts[!duplicated(rownames(sender_counts)),]
      } else {
        # If conversion failed, keep original names
        warning("Gene name conversion failed for sender_counts, using original names")
      }
    }, error = function(e) {
      warning("Error in gene name conversion for sender_counts: ", e$message)
    })
    
    ### Convert to human genes if the seurat object is in mouse gene reference: receiver_counts
    tryCatch({
      lookup <- homologene::mouse2human(rownames(receiver_counts), db = homologene::homologeneData2)
      new_rownames <- lookup$humanGene[match(rownames(receiver_counts), lookup$mouseGene)]
      
      # Check if new_rownames is valid and has the expected length
      if (length(new_rownames) == length(rownames(receiver_counts))) {
        for (newr in 1:length(new_rownames)){
          if (is.na(new_rownames[newr]) || is.null(new_rownames[newr]) || new_rownames[newr] == ""){
            new_rownames[newr] <- toupper(rownames(receiver_counts)[newr])
          }
        }
        rownames(receiver_counts) <- new_rownames
        receiver_counts <- receiver_counts[!duplicated(rownames(receiver_counts)),]
      } else {
        # If conversion failed, keep original names
        warning("Gene name conversion failed for receiver_counts, using original names")
      }
    }, error = function(e) {
      warning("Error in gene name conversion for receiver_counts: ", e$message)
    })
    
    rm(sender_seurat)
    rm(receiver_seurat)
    
    # 添加安全检查
    if(ncol(sender_counts) == 0 || ncol(receiver_counts) == 0) {
      warning("Sender or receiver counts matrix is empty")
      return(list(branch_graphs_list, list()))
    }
    
    # 安全的列数调整
    if(ncol(sender_counts) > ncol(receiver_counts)){
      if(ncol(receiver_counts) > 0) {
        sender_counts <- sender_counts[,1:ncol(receiver_counts), drop=FALSE]
      }
    } else {
      if(ncol(sender_counts) > 0) {
        receiver_counts <- receiver_counts[,1:ncol(sender_counts), drop=FALSE]
      }
    }
    
    # 再次检查调整后的矩阵
    if(ncol(sender_counts) == 0 || ncol(receiver_counts) == 0) {
      warning("After adjustment, sender or receiver counts matrix is empty")
      return(list(branch_graphs_list, list()))
    }
    
    new_pathway_df_list <- c()
    for(pathway_df in pathway_df_list){
      if(global_or_local == "global"){
        correlation_scores <- sapply(pathway_df[,2], find_global_spearman_correlation, source_ligand = pathway_df[1,1], seurat_object = seurat_object, sender_counts=sender_counts, receiver_counts=receiver_counts, sender_cell = sender_cell, target_cell = target_cell, exp_matrix_slot = exp_matrix_slot)
      }
      if(global_or_local == "local"){
        correlation_scores <- c()
        for(row in 1:nrow(pathway_df)){
          source_gene <- as.character(pathway_df[row,1])
          target_gene <- as.character(pathway_df[row,2])
          score <- find_local_spearman_correlation(receiver_counts = receiver_counts, source_gene = source_gene, target_gene = target_gene, target_cell = target_cell, exp_matrix_slot = exp_matrix_slot)
          correlation_scores[row]=score
        }
      }
      # # removed sign from the correlation score
      # pathway_df$Edge_weight <- pathway_df$DB_edge_correlation * correlation_scores
      if (global_or_local == "global"){
        pathway_df$Edge_weight <- abs(pathway_df$DB_edge_correlation) * pathway_df$Global_sign * abs(correlation_scores)
      } else {
        pathway_df$Edge_weight <- pathway_df$DB_edge_correlation * abs(correlation_scores)
      }
      
      ligand <- as.character(pathway_df[1,1])
      # vertices <- unique(c(pathway_df[1,1], pathway_df[,2]))
      vertices <- unique(c(pathway_df[,1], pathway_df[,2]))
      pathway <- pathway_df[-1,]
      pathway_ids <- unique(c(pathway[,1], pathway[,2]))
      user_pathway <- receiver_df[(toupper(receiver_df$gene)) %in% pathway_ids,]
      ligand_row <- sender_df[sender_df$gene == ligand,]
      overall <- rbind(ligand_row, user_pathway)
      overall$logFC_color <- ifelse(overall$avg_log2FC == 0, "Grey", 
                                    ifelse(overall$avg_log2FC > 0, "Red", "Blue"))
      pathway_branch_order <- str_split(pathway_df[1,]$Branch_path, "___")
      overall <- overall[match(pathway_branch_order[[1]], overall$gene),]
      overall <- overall[!duplicated(overall$gene),] # remove any duplicates
      if(length(c(pathway_ids, ligand)) == nrow(overall)){
        branch_graph <- graph_from_data_frame(pathway_df, vertices = vertices, directed = TRUE)
        # V(branch_graph)$weight <- c(overall[1,]$Vertex_weight, overall[-1,]$Vertex_weight * pathway_df$Edge_weight)
        V(branch_graph)$weight <- c(overall[1,]$Vertex_weight, overall[-1,]$Vertex_weight) # Removed the effect of edge weight
        V(branch_graph)$logFC <- overall$avg_log2FC
        V(branch_graph)$color <- overall$logFC_color
        E(branch_graph)$weight <- pathway_df$Edge_weight
        E(branch_graph)$color <- pathway_df$DB_edge_color
        branch_graphs_list[[i]] <- branch_graph
        new_pathway_df_list[[i]] <- pathway_df
        i <- i + 1
      }
      setTxtProgressBar(progress_bar, i)
    }
    close(progress_bar)
    return(list(branch_graphs_list, new_pathway_df_list))
  })
}


create_node_exp_table <- function(activated_pathways_overview_df, sender_df, receiver_df){
  sender_df <- as.data.frame(sender_df)
  receiver_df <- as.data.frame(receiver_df)
  sender_ligands <- unique(activated_pathways_overview_df[activated_pathways_overview_df$Signaling_protein == "Ligand",]$From)
  receiver_genes <- unique(c(activated_pathways_overview_df[activated_pathways_overview_df$Signaling_protein != "Ligand",]$From, 
                             activated_pathways_overview_df[activated_pathways_overview_df$Signaling_protein != "Ligand",]$To))
  sender_list <- sender_df[sender_df$gene %in% sender_ligands,]
  receiver_list <- receiver_df[receiver_df$gene %in% receiver_genes,]
  fc_df <- rbind(sender_list, receiver_list)
  fc_df <- fc_df[,c("gene", "avg_log2FC", "p_val_adj", "Vertex_weight")]
  fc_df <- fc_df[order(fc_df$gene),]
}