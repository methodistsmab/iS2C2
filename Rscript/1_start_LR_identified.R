suppressPackageStartupMessages({
library(igraph)
library(stringr)
library(readxl)
library(reshape)
library(plyr)
library(dplyr)
})

##################### NECESSARY DATAFRAMES ##############################
#make ligand to target one direction pathways
pathway_one_directional <- function(edge_dataframe){
  edges <- edge_dataframe[,c(1,2)]
  edges$Conc.e <- paste0(edges[,1], edges[,2])
  reversed <- edge_dataframe[,c(2,1)]
  reversed$Conc.r <- paste0(reversed[,1], reversed[,2])
  matches <- edges$Conc.e %in% reversed$Conc.r
  remove_index <- which(matches==TRUE)
  remove_index <- remove_index[seq_along(remove_index) %% 2 > 0]
  # if there is no duplicate, do not remove any ligand/receptor from the edge_dataframe
  if (length(remove_index) == 0 ){
    edge_dataframe <- edge_dataframe
  } else{
    edge_dataframe <- edge_dataframe[-remove_index,]
  }
  return(edge_dataframe)
}


prepare_database <- function(list_of_databases, disease="AD"){
  collective_database <- do.call(rbind, list_of_databases)
  collective_database$From <- toupper(collective_database$From)
  collective_database$To <- toupper(collective_database$To)
  collective_database$Conc <- paste0(collective_database$From, collective_database$To)
  #remove cancer related pathways if the disease is AD
  if(disease == "AD"){collective_database <- collective_database[!grepl("cancer", collective_database$Pathway_name),]}
  #assign edge weight of -1, 0.5, or +1 depending on interaction type between two genes
  collective_database <- collective_database %>%
    dplyr::mutate(DB_edge_correlation = dplyr::case_when(
      endsWith(Type, "process(activation)") ~ 1,
      endsWith(Type, "activation") ~ 1,
      endsWith(Type, "process(phosphorylation)") ~ 1,
      endsWith(Type, "phosphorylation") ~ 1,
      endsWith(Type, "process(expression)") ~ 1,
      endsWith(Type, "causation") ~ 1,
      endsWith(Type, "expression") ~ 1,
      endsWith(Type, "state") ~ 1,
      endsWith(Type, "process(binding/association)") ~ 1,
      endsWith(Type, "binding/association") ~ 1,
      endsWith(Type, "binding") ~ 1,
      endsWith(Type, "process(indirect effect)") ~ 0.5,
      endsWith(Type, "process(indirect)") ~ 0.5,
      endsWith(Type, "process(dissociation)") ~ -1,
      endsWith(Type, "process(dephosphorylation)") ~ -1,
      endsWith(Type, "process(inhibition)") ~ -1,
      endsWith(Type, "inhibition") ~ -1,
    ))
  collective_database[["DB_edge_correlation"]][is.na(collective_database[["DB_edge_correlation"]])] <- 0.25
  collective_database <- collective_database %>%
    dplyr::mutate(DB_edge_color = dplyr::case_when(
      endsWith(Type, "process(activation)") ~ "Red",
      endsWith(Type, "activation") ~ "Red",
      endsWith(Type, "process(phosphorylation)") ~ "Red",
      endsWith(Type, "phosphorylation") ~ "Red",
      endsWith(Type, "process(expression)") ~ "Red",
      endsWith(Type, "causation") ~ "Red",
      endsWith(Type, "expression") ~ "Red",
      endsWith(Type, "state") ~ "Green",
      endsWith(Type, "process(binding/association)") ~ "Green",
      endsWith(Type, "binding/association") ~ "Green",
      endsWith(Type, "binding") ~ "Green",
      endsWith(Type, "process(indirect effect)") ~ "Green",
      endsWith(Type, "process(indirect)") ~ "Green",
      endsWith(Type, "process(dissociation)") ~ "Blue",
      endsWith(Type, "process(dephosphorylation)") ~ "Blue",
      endsWith(Type, "process(inhibition)") ~ "Blue",
      endsWith(Type, "inhibition") ~ "Blue",
    ))
  collective_database[["DB_edge_color"]][is.na(collective_database[["DB_edge_color"]])] <- "Green"
  collective_database <- pathway_one_directional(collective_database)
  return(collective_database)
}

#################### SENDER AND RECEIVER ##############################

#find markers and overall expression for sender and receiver cells
find_sender_receiver_genes <- function(seurat_object, specified_sender, specified_receiver, condition_colname, condition1, condition2=NA, percent_exp = 0.1, logfc_threshold = 0.25, assay){
  original_idents <- Idents(seurat_object)
  celltypes <- levels(Idents(seurat_object))

  DefaultAssay(seurat_object) <- assay

  if(is.na(condition2)==FALSE){
    md <- as.data.frame(seurat_object@meta.data)
    colname_index <- which(colnames(md)==condition_colname)
    md$celltype.stim <- paste(Idents(seurat_object), md[,colname_index], sep = "_")
    seurat_object$celltype.stim <- md$celltype.stim
    seurat_object$celltype <- Idents(seurat_object)
    Idents(seurat_object) <- "celltype.stim"
    sender_markers <- FindMarkers(seurat_object, ident.1 = paste(specified_sender, condition1, sep = "_"), ident.2 = paste(specified_sender, condition2, sep = "_"), features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox")
    sender_markers$gene <- rownames(sender_markers)
    sender_markers$condition <- condition2 # added for prepare_sender_receiver function
    receiver_genes <- FindMarkers(seurat_object, ident.1 = paste(specified_receiver, condition1, sep = "_"), ident.2 = paste(specified_receiver, condition2, sep = "_"), features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox")
    receiver_genes$gene <- rownames(receiver_genes)
    receiver_genes$condition <- condition2 # added for prepare_sender_receiver function
    
    ## Use FindMarkers function on all cell types so that we can later refer to it.
    markers_df <- list()
    for (i in 1:length(celltypes)){
      markers_celltype <- FindMarkers(seurat_object, ident.1 = paste(celltypes[i], condition1, sep = "_"), ident.2 = paste(celltypes[i], condition2, sep = "_"), features = rownames(seurat_object), min.pct = 0, verbose = FALSE, logfc.threshold = 0, test.use = "wilcox")
      markers_df[[i]] <- markers_celltype
    }
    Idents(seurat_object) <- original_idents
  } else {
    seurat_object <- seurat_object[, seurat_object@meta.data[, condition_colname] == condition1]
    sender_markers <- FindMarkers(seurat_object, ident.1 = specified_sender, features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox")
    sender_markers$gene <- rownames(sender_markers)
    sender_markers$condition <- condition1
    receiver_genes <- FindMarkers(seurat_object, ident.1 = specified_receiver, features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox")
    receiver_genes$gene <- rownames(receiver_genes)
    receiver_genes$condition <- condition1
    
    ## Use FindMarkers function on all cell types so that we can later refer to it.
    markers_df <- list()
    for (i in 1:length(celltypes)){
      markers_celltype <- FindMarkers(seurat_object, ident.1 = paste(celltypes[i]), features = rownames(seurat_object), min.pct = 0, verbose = FALSE, logfc.threshold = 0, test.use = "wilcox")
      markers_df[[i]] <- markers_celltype
    }
  }
  dataframes <- list(sender_markers, receiver_genes)
  names(dataframes) <- c(paste0("Sender_Markers_", specified_sender), paste0("Receiver_Overall_", specified_receiver))
  return(list(dataframes, markers_df))
}

#find markers and overall expression for sender and receiver cells
find_sender_receiver_genes_subset <- function(seurat_object, specified_sender, specified_receiver, condition_colname, condition1, condition2=NA, percent_exp = 0.1, logfc_threshold = 0.25){
  original_idents <- Idents(seurat_object)
  celltypes <- levels(Idents(seurat_object))
  if(is.na(condition2)==FALSE){
    md <- as.data.frame(seurat_object@meta.data)
    colname_index <- which(colnames(md)==condition_colname)
    md$celltype.stim <- paste(Idents(seurat_object), md[,colname_index], sep = "_")
    seurat_object$celltype.stim <- md$celltype.stim
    seurat_object$celltype <- Idents(seurat_object)
    Idents(seurat_object) <- "celltype.stim"
    sender_markers <- FindMarkers(seurat_object, ident.1 = paste(specified_sender, condition1, sep = "_"), ident.2 = paste(specified_sender, condition2, sep = "_"), features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox", recorrect_umi=FALSE)
    sender_markers$gene <- rownames(sender_markers)
    sender_markers$condition <- condition2 # added for prepare_sender_receiver function
    receiver_genes <- FindMarkers(seurat_object, ident.1 = paste(specified_receiver, condition1, sep = "_"), ident.2 = paste(specified_receiver, condition2, sep = "_"), features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox",recorrect_umi=FALSE)
    receiver_genes$gene <- rownames(receiver_genes)
    receiver_genes$condition <- condition2 # added for prepare_sender_receiver function
    
    ## Use FindMarkers function on all cell types so that we can later refer to it.
    markers_df <- list()
    new_celltypes <- levels(Idents(seurat_object))
    z=1
    for (i in 1:length(celltypes)){
      sender = paste(celltypes[i], condition1, sep = "_")
      receiver = paste(celltypes[i], condition2, sep = "_")
      if (sender %in% new_celltypes && receiver %in% new_celltypes){
        markers_celltype <- FindMarkers(seurat_object, ident.1 = paste(celltypes[i], condition1, sep = "_"), ident.2 = paste(celltypes[i], condition2, sep = "_"), features = rownames(seurat_object), min.pct = 0, verbose = FALSE, logfc.threshold = 0, test.use = "wilcox",recorrect_umi=FALSE)
        markers_df[[z]] <- markers_celltype
        markers_df[[z]]$celltype <- celltypes[i]
        z=z+1
      }
    }
    Idents(seurat_object) <- original_idents
  } else {
    seurat_object <- seurat_object[, seurat_object@meta.data[, condition_colname] == condition1]
    sender_markers <- FindMarkers(seurat_object, ident.1 = specified_sender, features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox",recorrect_umi=FALSE)
    sender_markers$gene <- rownames(sender_markers)
    sender_markers$condition <- condition1
    receiver_genes <- FindMarkers(seurat_object, ident.1 = specified_receiver, features = rownames(seurat_object), min.pct = percent_exp, verbose = FALSE, logfc.threshold = logfc_threshold, test.use = "wilcox",recorrect_umi=FALSE)
    receiver_genes$gene <- rownames(receiver_genes)
    receiver_genes$condition <- condition1
    
    ## Use FindMarkers function on all cell types so that we can later refer to it.
    markers_df <- list()
    for (i in 1:length(celltypes)){
      markers_celltype <- FindMarkers(seurat_object, ident.1 = paste(celltypes[i]), features = rownames(seurat_object), min.pct = 0, verbose = FALSE, logfc.threshold = 0, test.use = "wilcox",recorrect_umi=FALSE)
      markers_df[[i]] <- markers_celltype
    }
  }
  dataframes <- list(sender_markers, receiver_genes)
  names(dataframes) <- c(paste0("Sender_Markers_", specified_sender), paste0("Receiver_Overall_", specified_receiver))
  return(list(dataframes, markers_df))
}

prepare_sender_receiver <- function(sender_markers_df, receiver_overall_df, collective_database, logfc_threshold = 0.20, condition1, condition2=NA){

 # Modified to filter any sender genes with negative log2FC.
  sender <- sender_markers_df[sender_markers_df$avg_log2FC > 0 &sender_markers_df$pct.1 > 0 & sender_markers_df$pct.2 > 0,]
  receiver <- receiver_overall_df[receiver_overall_df$pct.1 > 0 & receiver_overall_df$pct.2 > 0,]
  collective_database_genes <- unique(c(collective_database[,1], collective_database[,2]))
  sender$avg_log2FC <- replace(sender$avg_log2FC, sender$avg_log2FC == 0.000000e+00, .Machine$double.xmin)
  receiver$avg_log2FC <- replace(receiver$avg_log2FC, receiver$avg_log2FC == 0.000000e+00, .Machine$double.xmin)
  sender$p_val_adj <- replace(sender$p_val_adj, sender$p_val_adj == 0, .Machine$double.xmin)
  receiver$p_val_adj <- replace(receiver$p_val_adj, receiver$p_val_adj == 0, .Machine$double.xmin)
  sender$Vertex_weight <- sender$avg_log2FC # removed p-value input
  receiver$Vertex_weight <- receiver$avg_log2FC 
  sender$gene <- toupper(sender$gene)
  receiver$gene <- toupper(receiver$gene)
  receiver_not_exp <- setdiff(collective_database_genes, receiver$gene)
  #if coming from seurat object
  if(is.na(condition2)==TRUE){ # changed the logical to TRUE(from FALSE) so that it makes sense
    receiver_not_exp_df <- data.frame(p_val = 1, avg_log2FC = 0, pct.1 = 1, pct.2 = 1, p_val_adj = 1, gene = receiver_not_exp, condition = condition1, Vertex_weight = 0)
  } else {
    receiver_not_exp_df <- data.frame(p_val = 1, avg_log2FC = 0, pct.1 = 1, pct.2 = 1, p_val_adj = 1, gene = receiver_not_exp,
                                      condition = condition2, Vertex_weight = 0)
  }

  receiver_all <- rbind(receiver, receiver_not_exp_df)
  receiver_all$gene <- toupper(receiver_all$gene)
  dataframes <- list(sender, receiver, receiver_all)
  names(dataframes) <- c("sender_dataframe", "receiver_dataframe", "receiver_all_dataframe")
  return(dataframes)
}

####### PERMUTE LIGAND & RECEPTOR AMONGST OTHER CLUSTERS ############
find_percent_exp <- function(seurat_object, gene, celltype){
  seurat_object <- subset(seurat_object, idents = celltype)
  first <- as.character(rownames(seurat_object)[1])
  if(stringr::str_detect(first, "[[:lower:]]") == FALSE){
    percentage_exp <- sum(GetAssayData(object = seurat_object, slot = "data")[gene,]>0)/nrow(seurat_object@meta.data)
  } else {
    gene <- str_to_title(gene)
    percentage_exp <- sum(GetAssayData(object = seurat_object, slot = "data")[gene,]>0)/nrow(seurat_object@meta.data)
  }
  if(length(percentage_exp) < 1){
    percentage_exp <- as.numeric(0)
  }
  return(percentage_exp)
}

find_avg_log2fc <- function(seurat_object, gene, celltype, condition_colname, condition1, condition2=NA){
  if(is.na(condition2)==FALSE){
    md <- as.data.frame(seurat_object@meta.data)
    colname_index <- which(colnames(md)==condition_colname)
    md$celltype.stim <- paste(Idents(seurat_object), md[,colname_index], sep = "_")
    seurat_object$celltype.stim <- md$celltype.stim
    seurat_object$celltype <- Idents(seurat_object)
    Idents(seurat_object) <- "celltype.stim"
    frame <- FindMarkers(seurat_object, ident.1 =  paste0(celltype, "_", condition1), ident.2 = paste0(celltype, "_", condition2), features = gene, verbose = FALSE, logfc.threshold = 0, min.pct = 0)
    value <- as.numeric(frame$avg_log2FC)
    Idents(seurat_object) <- seurat_object$celltype
  } else {
    frame <- FindMarkers(seurat_object, ident.1 = celltype, features = gene, verbose = FALSE, logfc.threshold = 0, min.pct = 0)
    value <- as.numeric(frame$avg_log2FC)
  }
  if(length(value) < 1){
    value <- as.numeric(0)
  }
  return(value)
}

find_ligand_receptor_significance <- function(seurat_object, markers_df, sender_df, receiver_df, ligand, receptor, specified_sender, specified_receiver, condition_colname, condition1, condition2 = NA){
  celltypes <- levels(Idents(seurat_object))
  ligand_fc <- c()
  ligand_percent <- c()
  receptor_fc <-c()
  receptor_percent <- c()
  for (i in 1:length(celltypes)){
    ligand_idx <- which(rownames(markers_df[[i]]) == ligand)
    if (length(ligand_idx)==0){
      ligand_fc <- c(ligand_fc, 0)
      ligand_percent <- c(ligand_percent, 0)
    } else{
      ligand_fc <- c(ligand_fc, markers_df[[i]]$avg_log2FC[ligand_idx])
      ligand_percent <- c(ligand_percent, markers_df[[i]]$pct.1[ligand_idx])
    }
    receptor_idx <- which(rownames(markers_df[[i]]) == receptor)
    if (length(receptor_idx)==0){
      receptor_fc <- c(receptor_fc, 0)
      receptor_percent <- c(receptor_percent, 0)
    } else{
      receptor_fc <- c(receptor_fc, markers_df[[i]]$avg_log2FC[receptor_idx])
      receptor_percent <- c(receptor_percent, markers_df[[i]]$pct.1[receptor_idx])
    }
  }

  ligands_score <- ligand_fc * ligand_percent
  ligand_avg <- mean(ligands_score)
  receptors_score <- receptor_fc * receptor_percent
  receptor_avg <- mean(receptors_score)

#   #normalization
  norm_denominator <- mean(c(ligand_avg, receptor_avg))
  #finds the mean LR score per cell-cell crosstalk
  LR_matrix <- outer(as.numeric(ligands_score), as.numeric(receptors_score), "+") / 2
  LR_matrix <- LR_matrix / norm_denominator

  rownames(LR_matrix) <- celltypes
  colnames(LR_matrix) <- celltypes

  specified_crosstalk <- as.numeric(LR_matrix[which(rownames(LR_matrix)==specified_sender), which(colnames(LR_matrix)==specified_receiver)])
  possible_crosstalks <- unlist(as.list(LR_matrix))
  possible_crosstalks <- possible_crosstalks[is.na(possible_crosstalks)==FALSE]
  if (is.na(specified_crosstalk)){specified_crosstalk=0}
  if(specified_crosstalk > 0) {
    possible_crosstalks <- sort(possible_crosstalks, decreasing = TRUE)
  } else {
    possible_crosstalks <- sort(possible_crosstalks, decreasing = FALSE)
  }
  rank <- which(possible_crosstalks == specified_crosstalk)
  score <- rank / length(possible_crosstalks)
  normalized_enrichment_score <- specified_crosstalk
  enrichment_score <- specified_crosstalk * norm_denominator
  return(c(score, normalized_enrichment_score, enrichment_score))
}


find_ligand_receptor_significance_subset <- function(seurat_object, markers_df, sender_df, receiver_df, ligand, receptor, specified_sender, specified_receiver, condition_colname, condition1, condition2 = NA){
  celltypes <- levels(Idents(seurat_object))
  ligand_fc <- c()
  ligand_percent <- c()
  receptor_fc <-c()
  receptor_percent <- c()
  newcelltypes <- c()
  for (i in 1:length(markers_df)){
    ligand_idx <- which(rownames(markers_df[[i]]) == ligand)
    if (length(ligand_idx)==0){
      ligand_fc <- c(ligand_fc, 0)
      ligand_percent <- c(ligand_percent, 0)
    } else{
      ligand_fc <- c(ligand_fc, markers_df[[i]]$avg_log2FC[ligand_idx])
      ligand_percent <- c(ligand_percent, markers_df[[i]]$pct.1[ligand_idx])
    }
    receptor_idx <- which(rownames(markers_df[[i]]) == receptor)
    if (length(receptor_idx)==0){
      receptor_fc <- c(receptor_fc, 0)
      receptor_percent <- c(receptor_percent, 0)
    } else{
      receptor_fc <- c(receptor_fc, markers_df[[i]]$avg_log2FC[receptor_idx])
      receptor_percent <- c(receptor_percent, markers_df[[i]]$pct.1[receptor_idx])
    }
    newcelltypes <- c(newcelltypes, markers_df[[i]]$celltype[1])
  }

  ligands_score <- ligand_fc * ligand_percent
  ligand_avg <- mean(ligands_score)
  receptors_score <- receptor_fc * receptor_percent
  receptor_avg <- mean(receptors_score)
  #normalization
  norm_denominator <- mean(c(ligand_avg, receptor_avg))
  LR_matrix <- outer(as.numeric(ligands_score), as.numeric(receptors_score), "+") / 2
  LR_matrix <- LR_matrix / norm_denominator
  rownames(LR_matrix) <- newcelltypes
  colnames(LR_matrix) <- newcelltypes
  specified_crosstalk <- as.numeric(LR_matrix[which(rownames(LR_matrix)==specified_sender), which(colnames(LR_matrix)==specified_receiver)])
  possible_crosstalks <- unlist(as.list(LR_matrix))
  possible_crosstalks <- possible_crosstalks[is.na(possible_crosstalks)==FALSE]
  if (is.na(specified_crosstalk)){specified_crosstalk=0}
  if(specified_crosstalk > 0) {
    possible_crosstalks <- sort(possible_crosstalks, decreasing = TRUE)
  } else {
    possible_crosstalks <- sort(possible_crosstalks, decreasing = FALSE)
  }
  rank <- which(possible_crosstalks == specified_crosstalk)
  score <- rank / length(possible_crosstalks)
  normalized_enrichment_score <- specified_crosstalk
  enrichment_score <- specified_crosstalk * norm_denominator
  return(c(score, normalized_enrichment_score, enrichment_score))
}

############ IDENTIFY LIGAND RECEPTORS FROM EXPRESSION DATA #############

find_ligand_receptor_pairs <- function(seurat_object, markers_df, specified_sender, specified_receiver, sender_df, receiver_df, LR_database, condition_colname, condition1, condition2 = NA){
  source_ligands <- intersect(toupper(sender_df$gene), LR_database[,1])
  target_receptors <- intersect(toupper(receiver_df$gene), LR_database[,2])
  LR_selected_pairs <- c()
  LR_sig_scores <- c()
  norm_ER_scores <- c()
  ER_scores <- c()
  i <- 1 
  pb = txtProgressBar(min = 0, max = length(source_ligands), initial = 0) 
  pb_indx = 0
  for(ligand in source_ligands){
    setTxtProgressBar(pb,pb_indx)
    source_indeces <- which(LR_database[,1]==ligand)
    LR_source_selected <- LR_database[source_indeces,]
    for(receptor in target_receptors){
      if(receptor %in% LR_source_selected[,2]){
        LR_pair <- c(ligand, receptor)
        LR_selected_pairs[[i]] <- LR_pair
        sig_score <- find_ligand_receptor_significance(seurat_object = seurat_object, markers_df, sender_df, receiver_df, ligand, receptor, specified_sender, specified_receiver, condition_colname, condition1, condition2)
        LR_sig_scores[i] <- sig_score[1]
        norm_ER_scores[i] <- sig_score[2] 
        ER_scores[i] <- sig_score[3] 
        i <- i + 1
      }
    }
    pb_indx <- pb_indx +1
  }
  close(pb)
  if(is.null(LR_selected_pairs) == TRUE) {
    LR_selected_pairs_df <- "No Ligand Receptor Pairs identified"
  } else {
    LR_selected_pairs_df <- as.data.frame(do.call(rbind, LR_selected_pairs))
    colnames(LR_selected_pairs_df) <- c("Ligand", "Receptor")
    ligand_logfc <- c()
    receptor_logfc <- c()
    lignad_pct <- c()
    receptor_pct <- c()
    for (idx in 1:length(LR_selected_pairs_df$Ligand)){
      row = which(sender_df$gene == LR_selected_pairs_df$Ligand[idx])
      row2 = which(receiver_df$gene == LR_selected_pairs_df$Receptor[idx])
      ligand_logfc[idx] = sender_df$avg_log2FC[row]
      receptor_logfc[idx] = receiver_df$avg_log2FC[row2]
      lignad_pct[idx] = sender_df$pct.1[row]
      receptor_pct[idx] = receiver_df$pct.1[row2]
    }
    LR_selected_pairs_df$Ligand_foldChange <- ligand_logfc
    LR_selected_pairs_df$Receptor_foldChange <- receptor_logfc
    LR_selected_pairs_df$Ligand_percentExp <- lignad_pct
    LR_selected_pairs_df$Receptor_percentExp <- receptor_pct
    LR_selected_pairs_df$specificity_sig_score <- as.vector(LR_sig_scores)
    LR_selected_pairs_df$normalized_enrichment_score <- as.vector(norm_ER_scores)
    LR_selected_pairs_df$enrichment_score <- as.vector(ER_scores)
    LR_selected_pairs_df <- LR_selected_pairs_df[order(as.vector(-LR_selected_pairs_df$enrichment_score)),]
    LR_selected_pairs_df <- LR_selected_pairs_df[LR_selected_pairs_df$enrichment_score > 0,] #threshold the enrichment score > 0.25 (was >0 before)

    LR_selected_pairs_df <- LR_selected_pairs_df[LR_selected_pairs_df$Ligand_foldChange > 0,] 

    LR_selected_pairs_df <- LR_selected_pairs_df[LR_selected_pairs_df$Ligand_percentExp > 0.005,] 

    LR_selected_pairs_df <- LR_selected_pairs_df[LR_selected_pairs_df$Receptor_percentExp > 0.005,] 
  }
  return(LR_selected_pairs_df)
}


find_ligand_receptor_pairs_subset <- function(seurat_object, markers_df, specified_sender, specified_receiver, sender_df, receiver_df, LR_database, condition_colname, condition1, condition2 = NA){
  source_ligands <- intersect(toupper(sender_df$gene), LR_database[,1])
  target_receptors <- intersect(toupper(receiver_df$gene), LR_database[,2])
  LR_selected_pairs <- c()
  LR_sig_scores <- c()
  norm_ER_scores <- c()
  ER_scores <- c()
  i <- 1 
  pb = txtProgressBar(min = 0, max = length(source_ligands), initial = 0) 
  pb_indx = 0
  for(ligand in source_ligands){
    setTxtProgressBar(pb,pb_indx)
    source_indeces <- which(LR_database[,1]==ligand)
    LR_source_selected <- LR_database[source_indeces,]
    for(receptor in target_receptors){
      if(receptor %in% LR_source_selected[,2]){
        LR_pair <- c(ligand, receptor)
        LR_selected_pairs[[i]] <- LR_pair
        sig_score <- find_ligand_receptor_significance_subset(seurat_object = seurat_object, markers_df, sender_df, receiver_df, ligand, receptor, specified_sender, specified_receiver, condition_colname, condition1, condition2)
        LR_sig_scores[i] <- sig_score[1]
        norm_ER_scores[i] <- sig_score[2] 
        ER_scores[i] <- sig_score[3] 
        i <- i + 1
      }
    }
    pb_indx <- pb_indx +1
  }
  close(pb)
  if(is.null(LR_selected_pairs) == TRUE) {
    LR_selected_pairs_df <- "No Ligand Receptor Pairs identified"
  } else {
    LR_selected_pairs_df <- as.data.frame(do.call(rbind, LR_selected_pairs))
    colnames(LR_selected_pairs_df) <- c("Ligand", "Receptor")
    ligand_logfc <- c()
    receptor_logfc <- c()
    lignad_pct <- c()
    receptor_pct <- c()
    for (idx in 1:length(LR_selected_pairs_df$Ligand)){
      row = which(sender_df$gene == LR_selected_pairs_df$Ligand[idx])
      row2 = which(receiver_df$gene == LR_selected_pairs_df$Receptor[idx])
      ligand_logfc[idx] = sender_df$avg_log2FC[row]
      receptor_logfc[idx] = receiver_df$avg_log2FC[row2]
      lignad_pct[idx] = sender_df$pct.1[row]
      receptor_pct[idx] = receiver_df$pct.1[row2]
    }
    LR_selected_pairs_df$Ligand_foldChange <- ligand_logfc
    LR_selected_pairs_df$Receptor_foldChange <- receptor_logfc
    LR_selected_pairs_df$Ligand_percentExp <- lignad_pct
    LR_selected_pairs_df$Receptor_percentExp <- receptor_pct
    LR_selected_pairs_df$specificity_sig_score <- as.vector(LR_sig_scores)
    LR_selected_pairs_df$normalized_enrichment_score <- as.vector(norm_ER_scores)
    LR_selected_pairs_df$enrichment_score <- as.vector(ER_scores)
    LR_selected_pairs_df <- LR_selected_pairs_df[order(as.vector(-LR_selected_pairs_df$enrichment_score)),]
    LR_selected_pairs_df <- LR_selected_pairs_df[LR_selected_pairs_df$enrichment_score > 0,] #threshold the enrichment score > 0.25 (was >0 before)
  }
  return(LR_selected_pairs_df)
}




