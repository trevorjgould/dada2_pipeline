library(dada2)
path <- (".")
list.files(path)
# Forward and reverse fastq filenames have format: SAMPLENAME_R1_001.fastq and SAMPLENAME_R2_001.fastq
fnFs <- sort(list.files(path, pattern="_R1_001.fastq.gz", full.names = TRUE))
fnRs <- sort(list.files(path, pattern="_R2_001.fastq.gz", full.names = TRUE))
# Extract sample names, assuming filenames have format: SAMPLENAME_XXX.fastq
sample.names <- sapply(strsplit(basename(fnFs), "_"), `[`, 1)

# Place filtered files in filtered/ subdirectory
filtFs <- file.path(path, "filtered", paste0(sample.names, "_F_filt.fastq.gz"))
filtRs <- file.path(path, "filtered", paste0(sample.names, "_R_filt.fastq.gz"))
names(filtFs) <- sample.names
names(filtRs) <- sample.names

# 16s
out <- filterAndTrim(fnFs, filtFs, fnRs, filtRs, truncLen=c(240,200), maxN=0, maxEE=c(2,4), truncQ=2, rm.phix=TRUE, compress=TRUE, multithread=8)
out
#f2 <- list.files("filtered/")
#filtFs <- f2[grepl("_F_", f2) == TRUE]
#filtRs <- f2[grepl("_R_", f2) == TRUE]

#setwd("filtered/")
#dereplicate reads
derep_forward <- derepFastq(filtFs, verbose=TRUE)
names(derep_forward) <- sample.names # the sample names in these objects are initially the file names of the samples, this sets them to the sample names for the rest of the workflow
derep_reverse <- derepFastq(filtRs, verbose=TRUE)
names(derep_reverse) <- sample.names

# error models
errF <- learnErrors(derep_forward, multithread=8, randomize=TRUE)
errR <- learnErrors(derep_reverse, multithread=8, randomize=TRUE)

dadaFs <- dada(derep_forward, err=errF, multithread=8, pool="pseudo")
dadaRs <- dada(derep_reverse, err=errR, multithread=8, pool="pseudo")

merged_amplicons <- mergePairs(dadaFs, derep_forward, dadaRs, derep_reverse, trimOverhang=TRUE, minOverlap=20)

seqtab <- makeSequenceTable(merged_amplicons)
dim(seqtab)
saveRDS(seqtab, "seqtab.rds")

seqtab.nochim <- removeBimeraDenovo(seqtab, method="consensus", multithread=TRUE, verbose=TRUE)
dim(seqtab.nochim)
saveRDS(seqtab.nochim, "seqtab_nochim.rds")

  # set a little function
getN <- function(x) sum(getUniques(x))

  # making a little table
summary_tab <- data.frame(row.names=sample.names, dada2_input=out[,1],
               filtered=out[,2], dada_f=sapply(dadaFs, getN),
               dada_r=sapply(dadaRs, getN), merged=sapply(merged_amplicons, getN),nonchim=rowSums(seqtab.nochim))
write.table(summary_tab, file = "sequence_process_summary.txt", sep = "\t", quote=FALSE)

seqtab.nochim <- readRDS("seqtab_nochim.rds")

#TAXONOMY
taxasilva <- assignTaxonomy(seqtab.nochim, "/home/umii/public/dada2_taxonomy_references/silva_nr99_v138.1_train_set.fa", multithread=TRUE, outputBootstraps = TRUE)
taxasilva$tax <- addSpecies(taxasilva$tax, "/home/umii/public/dada2_taxonomy_references/silva_species_assignment_v138.1.fa")
saveRDS(taxasilva$tax, file = "taxIDsilva.rds")
saveRDS(taxasilva$boot, file = "taxIDsilva_bootstrap.rds")
both1 <- cbind(t(seqtab.nochim),taxasilva$tax, taxasilva$boot)
both2 <- cbind(t(seqtab.nochim),taxasilva$tax)
write.table(both1, file = "16S_combined_sequences_taxa_silva_boot.txt", sep = "\t", quote = FALSE, col.names=NA)
write.table(both2, file = "16S_combined_sequences_taxa_silva.txt", sep = "\t", quote = FALSE, col.names=NA)
quit("no")