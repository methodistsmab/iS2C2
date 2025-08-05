options(warn = -1)

suppressPackageStartupMessages({
library(Seurat)
library(SingleCellExperiment)
library(openxlsx)
library(presto)
library(jsonlite)
library(DescTools)
library(plyr)
library(dplyr)
library(homologene)
library(ggplot2)
library(reshape2)
library(stringr)
library(optparse)
})

save_dir <- getwd()

source(paste0(save_dir,"/Rscript/1_start_LR_identified.R"))
source(paste0(save_dir,"/Rscript/2_identify_select_pathways_backup.R"))
source(paste0(save_dir,"/Rscript/3_activated_pathways.R"))
source(paste0(save_dir,"/Rscript/4_permutation_for_significance.R"))
# source(paste0(save_dir,"/5_visualization.R"))

read_file <- function(file_path) {
  # Open the file in binary read mode
  file_conn <- file(file_path, "rb")
  
  # Read the binary data
  binary_data <- readBin(
    con = file_conn,
    what = "integer",
    n = 10
  )
  
  # Close the file connection
  close(file_conn)
  
  # Return the binary data
  return(binary_data)
}

LR_database = read_file(paste0(save_dir, '/data/LR_manual_revised.txt.encryted'))
TF_targets = read_file(paste0(save_dir, '/data/TF_targets.txt.encryted'))
kegg = read_file(paste0(save_dir, '/data/KEGG_all_edge_new.txt.encryted'))

print ("==================data loading completed=============")

nodeCount = 0
pathwayCount = 0

# Modified sanitize_filename function - replaces ALL special characters with underscore
sanitize_filename <- function(filename) {
  sanitized <- sapply(filename, function(x) {
    if (is.na(x) || is.null(x) || length(x) == 0 || x == "") {
      return("unknown")
    }
    
    result <- as.character(x)
    
    # Replace all special characters with single underscore
    result <- gsub("[^A-Za-z0-9]", "_", result)
    
    # Replace multiple consecutive underscores with single underscore
    result <- gsub("_{2,}", "_", result)
    
    # Remove leading and trailing underscores
    result <- gsub("^_+|_+$", "", result)
    
    if (result == "" || is.na(result)) {
      result <- "unknown"
    }
    
    return(result)
  }, USE.NAMES = FALSE)
  
  return(sanitized)
}

#  MAIN FUNCTION
S2C2 <- function(seurat_object, 
                 specified_sender, 
                 specified_receiver, 
                 exp_matrix_slot, 
                 global_or_local, 
                 export_directory_path, 
                 condition_colname, 
                 condition1, 
                 LR_database, 
                 TF_targets, 
                 pathway_database_list, 
                 condition2=NA, 
                 percent_exp = 0.1, 
                 logfc_threshold = 0.25, 
                 disease = "AD", 
                 intermediate_downstream_gene_num = 2, 
                 permutation_num = 500,
                 lambda = 1.0,
                 species = 'mice',
                 assay = "RNA"
                 ){
  
  print("Welcome to S2C2: single-Cell Cross Communication Explorer!")
  print(paste("Sender:", specified_sender))
  print(paste("Receiver:", specified_receiver))
  print(paste("Condition2:", condition2))
  
  if(dir.exists(export_directory_path) == FALSE){
    dir.create(export_directory_path)
  }

  clean_sender <- sanitize_filename(specified_sender)
  clean_receiver <- sanitize_filename(specified_receiver)
  clean_condition2 <- if(!is.na(condition2)) sanitize_filename(condition2) else NA
  
  # print(paste("After Processed Sender:", clean_sender))
  # print(paste("Aftter Processed Receiver:", clean_receiver))
  # print(paste("After processed Condition2:", clean_condition2))

  subfolder_name <- if(is.na(condition2) == FALSE) {
    paste0("sender_", clean_sender, "_receiver_", clean_receiver, "_", clean_condition2)
  } else {
    paste0("sender_", clean_sender, "_receiver_", clean_receiver, "_NA")
  }
  
  print(paste("Folder's name", subfolder_name))

  export_directory_path <- file.path(export_directory_path, subfolder_name)
  
  print(paste("Full Output directory:", export_directory_path))

  if (!dir.exists(export_directory_path)) {
    dir.create(export_directory_path, recursive = TRUE)
    print(paste("Folder was created successfully:", export_directory_path))
  } else {
    print(paste("Folder exists", export_directory_path))
  }
   
  #1: prepare external pathway databases
  collective_database <- prepare_database(pathway_database_list, disease = "AD")
  print("================== Database Preview (following collective_database is ) ==================")
  print(head(collective_database))
  print("==================== 1 ✅ ====================")

  #2: find differentially expressed genes for sender and overall expression for receiver
  print("Determining Overall Expression of Receiver and Differentially Expressed Genes for Sender")
  print(paste0("Specified Sender: ", specified_sender))
  print(paste0("Specified Receiver: ", specified_receiver))
  results <- find_sender_receiver_genes(seurat_object = seurat_object, specified_sender = specified_sender, specified_receiver = specified_receiver, condition_colname = condition_colname, condition1 = condition1, condition2 = condition2,
                                        percent_exp = percent_exp, logfc_threshold = logfc_threshold, assay)
  pre_dataframes <- results[[1]]
  markers_df <- results[[2]]
  print("==================== 2 ✅ ====================")
 
  if (species != 'human'){
    ### Modify the list to human gene names.
    df1_s <- paste0("Sender_Markers_", specified_sender)
    df2_r <- paste0("Receiver_Overall_", specified_receiver)
    
    lookup <- homologene::mouse2human(rownames(pre_dataframes[df1_s][[1]]), db = homologene::homologeneData2)
    new_rownames <- lookup$humanGene[match(rownames(pre_dataframes[df1_s][[1]]), lookup$mouseGene)]
    for (i in 1:length(new_rownames)){
      if (isTRUE(is.na(new_rownames[i]))){
        new_rownames[i] <- toupper(rownames(pre_dataframes[df1_s][[1]])[i])
      }
    }
    
    pre_dataframes[df1_s][[1]]$gene <- new_rownames
    pre_dataframes[df1_s][[1]] <- pre_dataframes[df1_s][[1]] %>% distinct(gene, .keep_all = TRUE)
    rownames(pre_dataframes[df1_s][[1]]) <- pre_dataframes[df1_s][[1]]$gene 
    
    # pre_dataframes[df2_r]
    lookup <- homologene::mouse2human(rownames(pre_dataframes[df2_r][[1]]), db = homologene::homologeneData2)
    new_rownames <- lookup$humanGene[match(rownames(pre_dataframes[df2_r][[1]]), lookup$mouseGene)]
    for (i in 1:length(new_rownames)){
      if (isTRUE(is.na(new_rownames[i]))){
        new_rownames[i] <- toupper(rownames(pre_dataframes[df2_r][[1]])[i])
      }
    }
    pre_dataframes[df2_r][[1]]$gene <- new_rownames
    pre_dataframes[df2_r][[1]] <- pre_dataframes[df2_r][[1]] %>% distinct(gene, .keep_all = TRUE)
    rownames(pre_dataframes[df2_r][[1]]) <- pre_dataframes[df2_r][[1]]$gene 
    
    # Markers_df
    for (mdf in 1:length(markers_df)){
      lookup <- homologene::mouse2human(rownames(markers_df[[mdf]]), db = homologene::homologeneData2)
      new_rownames <- lookup$humanGene[match(rownames(markers_df[[mdf]]), lookup$mouseGene)]
      for (i in 1:length(new_rownames)){
        if (isTRUE(is.na(new_rownames[i]))){
          new_rownames[i] <- toupper(rownames(markers_df[[mdf]])[i])
        }
      }
      markers_df[[mdf]]$gene <- new_rownames
      markers_df[[mdf]]<- markers_df[[mdf]][!duplicated(markers_df[[mdf]]$gene),]
      rownames(markers_df[[mdf]]) <- markers_df[[mdf]]$gene
    }
  }

  #3: prepare dataframes
  user_dataframes <- prepare_sender_receiver(pre_dataframes[[1]], pre_dataframes[[2]], collective_database, logfc_threshold = logfc_threshold, condition1 = condition1, condition2 = condition2)

  print("Exporting Sender Differentially Expressed Markers and Receiver Overall Expression Values")
  write.table(user_dataframes$sender_dataframe, paste0(export_directory_path, "/sender_markers_", clean_sender, ".txt"), quote = FALSE, sep = '\t', row.names = FALSE)
  write.table(user_dataframes$receiver_dataframe, paste0(export_directory_path, "/receiver_overall_", clean_receiver, ".txt"), quote = FALSE, sep = '\t', row.names = FALSE)
  print("==================== 3 ✅ ====================")

  #4: find expressed ligand receptors
  print("Finding Expressed Ligand Receptor Interactions (LR pairs)")
  ligand_receptor_dataframe <- find_ligand_receptor_pairs(seurat_object = seurat_object, markers_df = markers_df, specified_sender = specified_sender, specified_receiver = specified_receiver, sender_df = user_dataframes$sender_dataframe, receiver_df = user_dataframes$receiver_dataframe, 
                                                          LR_database = LR_database, condition_colname = condition_colname, condition1 = condition1, condition2 = condition2)
  
  if(length(ligand_receptor_dataframe) == 1){
    result <- "No Identified Ligand Receptor Pairs found in Crosstalk"
    print(result)
    write(result, paste0(export_directory_path, "/no_ligand_receptors.txt"))
  } else {
    print("Exporting Expressed Ligand Receptor Dataframe to export directory path")
    write.table(ligand_receptor_dataframe, paste0(export_directory_path, "/LR_pairs.txt"), quote = FALSE, row.names = FALSE, sep = '\t')
    print("==================== 4 ✅ ====================")

    #5: find activated pathways
    print("Finding Possible Pathways From Identified LR pairs")
    prelim_LRs <- find_preliminary_pathways(ligand_receptor_dataframe, collective_database)
    print("Finding Possible Activated Pathways")
    activated_pathways_overview <- find_activated_branches(prelim_LRs, user_dataframes$receiver_dataframe, intermediate_downstream_gene_num = intermediate_downstream_gene_num, TF_targets = TF_targets)
    if(length(activated_pathways_overview) == 1){
      result <- "S2C2 cannot continue crosstalk pathway analysis. User-specific downstream targets were not found in the expression data provided."
      print(result)
      write(result, paste0(export_directory_path, "/no_pathways.txt"))
    } else {
      node_table <- create_node_exp_table(activated_pathways_overview, user_dataframes$sender_dataframe, user_dataframes$receiver_all_dataframe)
      print("Exporting Node/Vertex table of avg_log2FC values to export directory path")
      write.table(node_table, paste0(export_directory_path, "/node_table_logFC.txt"), quote = FALSE, sep = '\t', row.names = FALSE)
      print("==================== 5 ✅ ====================")
      
      #6: assign weights to each graph
      print("Assigning User Specific Values to Each Activated Pathway Identified: ")
      if (species != 'human'){
        output <- construct_weighted_graph_ST(seurat_object, sender_cell = specified_sender, target_cell = specified_receiver, exp_matrix_slot = exp_matrix_slot, database_df = activated_pathways_overview, sender_df = user_dataframes$sender_dataframe, 
                                              receiver_df = user_dataframes$receiver_all_dataframe, global_or_local = global_or_local)
        weighted_graphs <- output[[1]]
        new_pathway_df_list <- output[[2]]
      } else {
        output <- construct_weighted_graph(seurat_object, sender_cell = specified_sender, target_cell = specified_receiver, exp_matrix_slot = exp_matrix_slot, database_df = activated_pathways_overview, sender_df = user_dataframes$sender_dataframe, 
                                           receiver_df = user_dataframes$receiver_all_dataframe, global_or_local = global_or_local)
        weighted_graphs <- output[[1]]
        new_pathway_df_list <- output[[2]]
      }
      print("==================== 6 ✅ ====================")
      
      #7: determine significance of each branch based on permutation test
      print("Calculating Pathway Significance by Permutation Test")
      final_dataframe <- find_sig_of_pathway_branches_v2(graph_list = weighted_graphs, export_directory_path=export_directory_path, collective_database = collective_database, overall_dataframe = new_pathway_df_list, receiver_df = user_dataframes$receiver_all_dataframe, permutation_num = permutation_num, lambda=lambda)
      print("Exporting Ranked Pathway's Significance to export directory path")
      write.table(final_dataframe, paste0(export_directory_path, "/significant_branches.txt"), sep = '\t', quote = FALSE, row.names = FALSE)
      print("==================== 7 ✅ ====================")

      # Generate LLM_significant_branches.csv for ligand-receptor interactions
      print("Generating LLM_significant_branches.csv for ligand-receptor interactions")
      old_output_sig_branches <- read.csv(paste0(export_directory_path, "/significant_branches.txt"), sep = '\t')
      cleaned_sig_braches <- old_output_sig_branches[old_output_sig_branches$Signaling_protein == 'Ligand',]
      cleaned_sig_braches <- cleaned_sig_braches[, c("from", "to", "Pathway_name", 'Database_source', 'Branch_path', 'p_val', 'PAS')]
      colnames(cleaned_sig_braches)[1] <- "ligand"
      colnames(cleaned_sig_braches)[2] <- "receptor"
      write.csv(cleaned_sig_braches, paste0(export_directory_path, "/LLM_significant_branches.csv"), row.names = FALSE)
      # write.csv(cleaned_sig_braches, file.path(save_dir, "LLM_significant_branches.csv"), row.names = FALSE)
      print("==================== LLM CSV ✅ ====================")

      significant_branches_path <- paste0(export_directory_path, "/significant_branches.txt")
      significant_branches <- read.delim(significant_branches_path, sep = "\t")

      parent_directory_path <- dirname(export_directory_path)

      sub_pathway_dir <- file.path(parent_directory_path, "sub_pathway")
      dir.create(sub_pathway_dir, showWarnings = FALSE, recursive = TRUE)

      # combined pathway
      combined_pathway <- significant_branches %>%
        select(from, to, Type, Signaling_protein) %>%
        mutate(
          Direction = "directed",
          Type = ifelse(Signaling_protein == "Ligand", "LR", Type)
        ) %>%
        select(from, to, Direction, Type) %>%
        distinct()

      pathwayCount <- nrow(combined_pathway)

      combined_pathway_path <- paste0(parent_directory_path, "/combined_pathway.txt")
      write.table(combined_pathway, combined_pathway_path, sep = "\t", row.names = FALSE, quote = FALSE)

      pathway_nodes_temp <- significant_branches %>%
        select(from, Signaling_protein, Pathway_name) %>%
        distinct()
      
      pathway_nodes <- pathway_nodes_temp %>%
        group_by(from) %>%
        summarise(
          gene_type = case_when(
            first(Signaling_protein) == "Signaling" ~ "links",
            first(Signaling_protein) == "Leaf" ~ "TF",
            TRUE ~ as.character(first(Signaling_protein))
          ),
          pathway = paste(unique(Pathway_name), collapse = ";"),
          .groups = 'drop'
        )
      
      colnames(pathway_nodes)[1] <- "gene"

      pathway_nodes_path <- paste0(parent_directory_path, "/combined_pathway_nodes.txt")

      pathway_nodes_unique <- pathway_nodes %>% 
        distinct(gene, .keep_all = TRUE)

      write.table(pathway_nodes_unique, pathway_nodes_path, sep = "\t", row.names = FALSE, quote = FALSE)

      nodeCount <- nrow(pathway_nodes)

      pathway_file_list <- significant_branches %>%
        select(Pathway_name, p_val) %>%
        distinct(Pathway_name, .keep_all = TRUE) %>%
        mutate(
          pathway_node_source = paste0(sanitize_filename(Pathway_name), "_nodes.txt"),
          pathway_source = paste0(sanitize_filename(Pathway_name), ".txt")
        ) %>%
        arrange(p_val) %>% 
        select(Pathway_name, p_val, pathway_node_source, pathway_source)

      pathway_file_list_path <- paste0(parent_directory_path, "/pathway_file_list.txt")
      write.table(pathway_file_list, pathway_file_list_path, sep = "\t", row.names = FALSE, quote = FALSE)

      pathway_file_list <- read.delim(pathway_file_list_path, sep = "\t")
      combined_pathway_nodes <- read.delim(pathway_nodes_path, sep = "\t")
      combined_pathway <- read.delim(combined_pathway_path, sep = "\t")

      for (py in pathway_file_list$Pathway_name) {
        clean_pathway_name <- sanitize_filename(py)
        print(paste("pathway:", py, "-> Cleaned pathway:", clean_pathway_name))
        
        # For pathway matching, we still need to use the original pathway name
        # because the pathway names in the data haven't been sanitized
        escaped_pathway <- str_replace_all(py, "\\(|\\)|\\[|\\]", "\\\\\\0")
        pattern <- paste0("(^|;)", escaped_pathway, "($|;)")

        pathway_nodes <- combined_pathway_nodes %>%
          filter(str_detect(pathway, regex(pattern, ignore_case = TRUE))) %>%
          distinct(gene, .keep_all = TRUE)
        
        # But use sanitized name for file creation
        write.table(pathway_nodes, 
                    file.path(sub_pathway_dir, paste0(clean_pathway_name, "_nodes.txt")),
                    sep = "\t", row.names = FALSE, quote = FALSE, col.names = TRUE)

        pathway_edges <- combined_pathway %>%
          filter(from %in% pathway_nodes$gene & to %in% pathway_nodes$gene)
          
        write.table(pathway_edges, 
                    file.path(sub_pathway_dir, paste0(clean_pathway_name, ".txt")), 
                    sep = "\t", row.names = FALSE, quote = FALSE, col.names = TRUE)
      }

      print("S2C2 Complete!")

      return(list(nodeCount = nodeCount, pathwayCount = pathwayCount))
    }
  }
}

load(paste0(save_dir, '/data/init.RData'))

# FIXED VARIABLE
pathway_database_list = list(kegg)

# SYSTEM FETCH SYSTEM ARGUMENTS
# print('DEBUG: commandArgs(trailingOnly = TRUE):')
# print(commandArgs(trailingOnly = TRUE))

option_list = list(
  make_option(c("--rds-file"), type="character", help="Path to RDS file", metavar="FILE"),
  make_option(c("--celltype-colname"), type="character", help="Cell type column name"),
  make_option(c("--condition-colname"), type="character", help="Condition column name"),
  make_option(c("--condition1"), type="character", help="Primary condition value"),
  make_option(c("--condition2"), type="character", default=NA, help="Secondary condition value [default %default]"),
  make_option(c("--sender"), type="character", help="Sender cell type"),
  make_option(c("--receiver"), type="character", help="Receiver cell type"),
  make_option(c("--percent-exp"), type="double", default=0.005, help="Percent expression threshold [default %default]"),
  make_option(c("--logfc-threshold"), type="double", default=0.20, help="LogFC threshold [default %default]"),
  make_option(c("--intermediate-downstream-gene-num"), type="integer", default=2, help="Intermediate downstream gene number [default %default]"),
  make_option(c("--permutation-num"), type="integer", default=1000, help="Permutation number [default %default]"),
  make_option(c("--lambda"), type="double", default=0.0, help="Lambda parameter [default %default]"),
  make_option(c("--species"), type="character", default="mouse", help="Species (mouse/human) [default %default]"),
  make_option(c("--assay"), type="character", default="RNA", help="Assay type (RNA/integrated) [default %default]"),
  make_option(c("--disease"), type="character", default="AD", help="Disease context [default %default]"),
  make_option(c("--results-dir"), type="character", default="results", help="Results output directory [default %default]")
)

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

# print('DEBUG: optparse result:')
# print(opt)

# ---- Custom validation (following original logic) ----

# print(opt[["rds-file"]])
# print(opt[["celltype-colname"]])
# print(opt[["condition-colname"]])
# print(opt[["condition1"]])
# print(opt[["condition2"]])
# print(opt[["sender"]])
# print(opt[["receiver"]])
# print(opt[["percent-exp"]])
# print(opt[["logfc-threshold"]])
# print(opt[["intermediate-downstream-gene-num"]])
# print(opt[["permutation-num"]])
# print(opt[["lambda"]])
# print(opt[["species"]])
# print(opt[["assay"]])
# print(opt[["disease"]])
# print(opt[["results-dir"]])


# Required file existence
if (is.null(opt[["rds-file"]]) || !file.exists(opt[["rds-file"]])) {
  stop("❌ RDS file does not exist: ", opt[["rds-file"]])
}
if (is.null(opt[["celltype-colname"]])) stop("❌ --celltype-colname is required.")
if (is.null(opt[["condition-colname"]])) stop("❌ --condition-colname is required.")
if (is.null(opt[["condition1"]])) stop("❌ --condition1 is required.")
if (is.null(opt[["sender"]])) stop("❌ --sender is required.")
if (is.null(opt[["receiver"]])) stop("❌ --receiver is required.")

# Numeric range checks
if (!is.numeric(opt[["percent-exp"]]) || is.na(opt[["percent-exp"]]) || opt[["percent-exp"]] < 0 || opt[["percent-exp"]] > 1) {
  stop("❌ Error: percent_exp must be a numeric value between 0 and 1.")
}
if (!is.numeric(opt[["logfc-threshold"]]) || is.na(opt[["logfc-threshold"]]) || opt[["logfc-threshold"]] <= 0) {
  stop("❌ Error: logfc_threshold must be a numeric value greater than 0.")
}
if (!is.numeric(opt[["intermediate-downstream-gene-num"]]) || is.na(opt[["intermediate-downstream-gene-num"]]) || opt[["intermediate-downstream-gene-num"]] < 1) {
  stop("❌ Error: intermediate_downstream_gene_num must be a numeric value greater than 0.")
}
if (!is.numeric(opt[["permutation-num"]]) || is.na(opt[["permutation-num"]]) || opt[["permutation-num"]] < 1) {
  stop("❌ Error: permutation_num must be a numeric value greater than 0.")
}
if (!is.numeric(opt[["lambda"]]) || is.na(opt[["lambda"]]) || opt[["lambda"]] < 0 || opt[["lambda"]] > 1) {
  stop("❌ Error: lambda must be a numeric value between 0 and 1.")
}

# Allowed values
if (!(opt[["species"]] %in% c("mouse", "human"))) {
  stop("❌ The provided species value ", opt[["species"]], " is not valid. Valid values are: mouse or human")
}
if (!(opt[["assay"]] %in% c("RNA", "integrated"))) {
  stop("❌ The provided assay value ", opt[["assay"]], " is not valid. Valid values are: RNA or integrated")
}

# Now you can access arguments by name:
# opt$rds_file, opt$celltype_colname, opt$condition_colname, etc.

# GET RDS FILE DATA 
path_rds_file <- opt[["rds-file"]]
print(paste("Path_rds_file is ===> ", path_rds_file))
seurat_object = readRDS(path_rds_file)
metadata <- seurat_object@meta.data

user_celltype_colname <- opt[["celltype-colname"]]
if (!(user_celltype_colname %in% colnames(metadata))) {
    stop(paste("❌ The provided cell type column name", user_celltype_colname, "is not a valid column in the RDS file metadata."))
}

Idents(seurat_object) <- user_celltype_colname

unique_celltype = unique(Idents(seurat_object))
unique_column_name = colnames(metadata)
jsonlite::write_json(unique_celltype,  path = paste0(save_dir, "/celltype.json"))
jsonlite::write_json(metadata, path = paste0(save_dir, "/metadata.json"))
celltypes_str = paste(unique_celltype, collapse = ",")
writeLines(celltypes_str, con = paste0(save_dir, "/all_celltype.txt"))

condition_colname <- opt[["condition-colname"]]
if (!(condition_colname %in% unique_column_name)) {
    stop(paste("❌ The provided condition column name", condition_colname, "is not a valid column in the metadata."))
}
print(paste("Condition_colname is ===> ", condition_colname))
unique_values <- unique(seurat_object@meta.data[[condition_colname]])

condition1 <- opt[["condition1"]]

if (!(condition1 %in% unique_values)) {
    stop(paste("❌ The provided condition value", condition1, "is not valid for the column", condition_colname, ". Valid values are:", paste(unique_values, collapse=", ")))
}

# print(paste("Phenotype1 is ===> ", condition1))
if (is.null(opt[["condition2"]]) || is.na(opt[["condition2"]]) || opt[["condition2"]] == "NA"){
  condition2 <- NA
} else {
  condition2 <- opt[["condition2"]]
  if (!(condition2 %in% unique_values) && !is.na(condition2)) {
      stop("❌ The provided condition2 value ", condition2, " is not valid for the column ", condition_colname, ". Valid values are: ", paste(unique_values, collapse=", "))
  }

   if (!is.na(condition2) && condition2 == condition1) {
        stop("❌ condition2 cannot be the same as condition1. Both are: ", condition1)
    }
}


# Get sender and receiver cell types directly from parameters
sender_celltype <- opt[["sender"]]
receiver_celltype <- opt[["receiver"]]

# Validate that sender and receiver cell types exist in the data
if (!(sender_celltype %in% unique_celltype)) {
    stop(paste("❌ The provided sender cell type", sender_celltype, "is not found in the data. Available cell types are:", paste(unique_celltype, collapse=", ")))
}

if (!(receiver_celltype %in% unique_celltype)) {
    stop(paste("❌ The provided receiver cell type", receiver_celltype, "is not found in the data. Available cell types are:", paste(unique_celltype, collapse=", ")))
}

print(paste("Sender cell type:", sender_celltype))
print(paste("Receiver cell type:", receiver_celltype))

# Create single-element lists for sender and receiver
sender_list <- c(sender_celltype)
receiver_list <- c(receiver_celltype)

global_method <- "global"


# （0 - 1)
percent_exp <- opt[["percent-exp"]]

# print(paste("percent_exp is ===> ", percent_exp))

logfc_threshold <- opt[["logfc-threshold"]]
# print(paste("logfc_threshold ===> ", logfc_threshold))

intermediate_downstream_gene_num <- opt[["intermediate-downstream-gene-num"]]
# print(paste("intermediate_downstream_gene_num is ===> ", intermediate_downstream_gene_num))

permutation_num <- opt[["permutation-num"]]
# print(paste("permutation_num is ===> ", permutation_num))

# USER INPUT VARIABLE
lambda <- opt[["lambda"]]

# print(paste("lambda is ===> ", lambda))

species <- opt[["species"]]


assay <- opt[["assay"]]

# print(paste("assay is ===> ", assay))


disease <- opt[["disease"]]
# print(paste("disease is ===> ", disease))

export_dir_name <- opt[["results-dir"]]
# print(paste("export_dir_name is ===> ", export_dir_name))

sender_receiver_list <- expand.grid(sender_list, receiver_list)

for (z in 1:nrow(sender_receiver_list)){
  print(paste("Combination", z, ":", sender_receiver_list[z,1], "->", sender_receiver_list[z,2]))
  
  results <- S2C2(seurat_object = seurat_object,
                specified_sender = sender_receiver_list[z,1],
               specified_receiver = sender_receiver_list[z,2],
               exp_matrix_slot = "data",
               global_or_local = global_method,
               condition_colname = condition_colname,
               condition1= condition1, 
               LR_database = LR_database,
               TF_targets = TF_targets,
               pathway_database_list=pathway_database_list,
               condition2= condition2,
               percent_exp = percent_exp, 
               logfc_threshold = logfc_threshold,
               intermediate_downstream_gene_num = intermediate_downstream_gene_num, 
               permutation_num = permutation_num ,
               export_directory_path = export_dir_name,
              lambda = lambda,
              species = species,
              disease = disease,
              assay = assay
  )

  if (!is.null(results)) {
    nodeCount <- results$nodeCount
    pathwayCount <- results$pathwayCount
  }
}

gc()

errMsg = "Found the pathways successfully."
errCode = 100


print("============ 🌟 ALL DONE! 🌟 ================")