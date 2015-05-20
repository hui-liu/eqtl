# Scripts to download, extract and harmonized TCGA SNP6 birdseed genotypes
# It will ask for TCGA credentials, read latest sdrf information, look for birdseed 
# data of only Blood Normals ("10"), and remove any aliquot barcode (and parent barcode)
# with items other than "prior malignancy" or "synchronous malignancy" in the TCCGA
# annotation database. It will then NA any birdseed genotype with quality > 0.1, change
# Affy SNP_A names to dbSNP names, remove none dbSNP SNPs, and output raw and curated 
# birdseed genotyping matrix file.  
# Need a file sdrf.list in the directory.  It has two columns: disease abbreviation
# and the latest SNP6 sdrf file
# Need a file annotation.tbl.rda in the "~/eqtl/" directory.  It is the TCGA annotation
# table object generated by GetAnnotationJSON and GetAnnotationTable functions
# Need a file /glusterfs/netapp/homes1/ZHANGZ18/meta/SNP_A2dbsnp.txt which contains
# SNP_A to dbSNP matching information

# load packages
options(stringsAsFactors=F)
source("~/github/eqtl/module.access.r")
source("~/github/eqtl/module.annotation.r")

# init: provide disease name and sdrf that contain file and aliquot information
sdrf.list <- read.delim("sdrf.list", h=F, stringsAsFactors=F)

# get username and password for TCGA protected data
cred <- GetTCGACredential()

# loop to get all diseases in the sdrf.list
for (i in 1: nrow(sdrf.list)) {
  disease <- tolower(sdrf.list$V1[i])
  sdrf.link <- sdrf.list$V2[i]

  # read sdrf as table
  sdrf <- GetTCGATable(sdrf.link, cred$username, cred$password)

  # extract information from sdrf
  file.info <- ProcessSNP6Sdrf(sdrf, disease)

  # Get Blood Normal only
  file.info <- file.info[substr(file.info$aliquot, 14, 15) == "10", ]

  # download all birdseed data provided by the urls, and combine to a matrix file
  geno <- GetGenotype(file.info$url.birdseed, file.info$file.birdseed, cred$username, cred$password)

  # save the birdseed matrix
  save(geno, file=paste0(disease, ".birdseed.rda"))

  # replace colnames with TCGA aliquot barcode, and rownames with dbSNP names
  colnames(geno) = file.info$aliquot
  conv <- read.table("/glusterfs/netapp/homes1/ZHANGZ18/meta/SNP_A2dbsnp.txt", as.is=T)
  rownames(geno) <- conv$V2[match(rownames(geno), conv$V1)]

  # remove SNPs without "rs" names
  geno <- geno[which(grepl("^rs", rownames(geno))), ]

  # load TCGA annotation table
  load("~/eqtl/annotation.tbl.rda") 

  # filter by annotation table 
  aliquots <- colnames(geno)
  aliquots <- FilterByAnnotation(aliquots, annot.tbl)
  geno <- geno[, which(colnames(geno) %in% aliquots)]

  # save the processed dbSNP matrix
  save(geno, file=paste0(disease, ".geno.rda"))
  
  # save aliquot names
  write.table(colnames(geno), paste0(disease, ".geno.aliquots"), col.names=F, row.names=F, quote=F, sep="\t")
}

