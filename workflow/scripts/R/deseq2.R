library(biomformat)
library(DESeq2)

log <- file(snakemake@log[[1]], open="wt")
sink(log)
sink(log, type="message")

print("Loading table...")
table <- biomformat::read_biom(snakemake@input[["table"]])
table <- as.matrix(biomformat::biom_data(table))

print("Loading metadata...")
metadata <- read.table(snakemake@input[["metadata"]], sep="\t", header=T,
                       row.names=1)

covariate <- snakemake@config[["model"]][["covariate"]]
target <- snakemake@config[["model"]][["target"]]
reference <- snakemake@config[["model"]][["reference"]]
confounders <- snakemake@config[["model"]][["confounders"]]

print("Harmonizing table and metadata samples...")
samples <- colnames(table)
metadata <- subset(metadata, rownames(metadata) %in% samples)
metadata[[covariate]] <- as.factor(metadata[[covariate]])
metadata[[covariate]] <- relevel(metadata[[covariate]], reference)
sample_order <- row.names(metadata)
table <- table[, sample_order]
# Append F_ to features to avoid R renaming
row.names(table) <- paste0("F_", row.names(table))

print("Creating design formula...")
design.formula <- paste0("~", covariate)
if (length(confounders) != 0) {
    confounders_form = paste(confounders, collapse=" + ")
    design.formula <- paste0(design.formula, " + ", confounders_form)
}
design.formula <- as.formula(design.formula)
print(design.formula)

print("Running DESeq2...")
dds <- DESeq2::DESeqDataSetFromMatrix(
    countData=table,
    colData=metadata,
    design=design.formula
)
dds.results <- DESeq2::DESeq(dds, sfType="poscounts")
saveRDS(dds.results, snakemake@output[[2]])
print("Saved RDS!")

results <- DESeq2::results(
    dds.results,
    format="DataFrame",
    tidy=TRUE,
    cooksCutoff=FALSE,
    contrast=c(covariate, target, reference)
)
row.names(results) <- gsub("^F_", "", row.names(table))
write.table(results, file=snakemake@output[[1]], sep="\t")
print("Saved differentials!")
