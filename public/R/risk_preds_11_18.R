## Toxicities: survival, feeding tube, aspiration
# Outputs: predicted toxicity probability for each patient, 
# predicted survival probability for each patient, 
# weight of each variable in each risk prediction model 

## load libraries
needs(survival)
needs(dplyr)
needs(purrr)

attach(input[[1]])

### set file direc# tory
## Modify this to correct file location
file.dir <- data_path

### load data
OPC <- read.csv(paste0(file.dir, "/Anonymized_644.Updated_cleaned_v1.3.1.csv"))
#length(unique(OPC$Dummy.ID))

###############################
##### Clean clinical data #####
###############################
## remove duplicates
OPC_final <- OPC
OPC_final_clinic <- OPC_final[, c(1:40)]
OPC_final_clinic <- mutate(OPC_final_clinic, 
                           ajcc_stage = as.character(AJCC.8th.edition),
                           T.category34 = ifelse(T.category == "T3" | T.category == "T4", 1, 0),
                           N.category23 = ifelse(N.category == "N2" | N.category == "N3", 1, 0),
                           white = ifelse(Race == "White/Caucasion", "White", "Other"),
                           smoke = Smoking.status.at.Diagnosis..Never.Former.Current.,
                           pack_year = ifelse(Smoking.status..Packs.Year. == "N/A", NA, as.numeric(Smoking.status..Packs.Year.)),
                           pack_year = ifelse(smoke == "Never", 0, pack_year),
                           pack_year = ifelse(is.na(pack_year) == TRUE, mean(pack_year, na.rm = TRUE), pack_year),
                           age = Age.at.Diagnosis..Calculated.,
                           neck_boost = Neck.boost..Y.N.,
                           neck_dissection = Neck.Disssection.after.IMRT..Y.N.,
                           tumor_subsite = as.factor(ifelse(!(Tumor.subsite..BOT.Tonsil.Soft.Palate.Pharyngeal.wall.GPS.NOS.%in%c("BOT","Tonsil")),"Other",
                                                            as.character(Tumor.subsite..BOT.Tonsil.Soft.Palate.Pharyngeal.wall.GPS.NOS.)))
)
levels(OPC_final_clinic$smoke )[levels(OPC_final_clinic$smoke )=="Formar"] <- "Former"
levels(OPC_final_clinic$T.category)[levels(OPC_final_clinic$T.category)=="Tis"] <- "T1"
levels(OPC_final_clinic$T.category)[levels(OPC_final_clinic$T.category)=="Tx"] <- "T1"
## 2 blanks for feeding tube - omit
OPC_final_clinic <- OPC_final_clinic[OPC_final_clinic$Feeding.tube.6m!="",]
OPC_final_clinic <- mutate(OPC_final_clinic,
                           feeding_tube = ifelse(Feeding.tube.6m =="N",0,1),
                           aspiration = ifelse(Aspiration.rate.Y.N.=="N",0,1),
                           neck_boost = factor(OPC_final_clinic$neck_boost),
                           neck_dissection = factor(OPC_final_clinic$neck_dissection),
                           HPV.P16.status = factor(OPC_final_clinic$HPV.P16.status))
## select covariates to include
rel_vars <- c("Gender", "age", "HPV.P16.status", "T.category", "N.category",
              "smoke", "white", "pack_year","tumor_subsite","neck_boost","neck_dissection")

########################################
##### Feeding tube: binary outcome #####
########################################

## Relevel factor variables to yield positive coefficients
OPC_final_clinic$Gender <- factor(OPC_final_clinic$Gender,levels=levels(factor(OPC_final_clinic$Gender))[2:1])
OPC_final_clinic$smoke <- factor(OPC_final_clinic$smoke)
OPC_final_clinic$smoke <- relevel(OPC_final_clinic$smoke,"Former")
OPC_final_clinic$white <- factor(OPC_final_clinic$white,levels=c("White","Other"))
OPC_final_clinic$tumor_subsite <- relevel(OPC_final_clinic$tumor_subsite,"Tonsil")
OPC_final_clinic$neck_boost <- relevel(OPC_final_clinic$neck_boost,"Y")

## Logistic regression for feeding tube outcome
## Logistic regression model with main effects
fmla_ft <- as.formula(paste0("feeding_tube ~",paste0(rel_vars,collapse="+")))
fit_ft <- glm(fmla_ft, data=OPC_final_clinic, family="binomial")

######################################
##### Aspiration: binary outcome #####
######################################
OPC_final_clinic$white <- factor(OPC_final_clinic$white,levels=c("Other","White"))
## Logistic regression model with main effects
fmla_asp <- as.formula(paste0("aspiration ~",paste0(rel_vars,collapse="+")))
fit_asp <- glm(fmla_asp,data=OPC_final_clinic,family="binomial")
## note high correlation between 2 binary outcomes 

######################################
##### Survival: censored outcome #####
######################################
### outcome
# 1) overall - overall survival (OS)
#	2) PFS - progression (local, regional, and distant control) free survival 

## Add survival time and indicator variables to dataset for OS 
OPC_final_surv <- OPC_final_clinic
OPC_final_surv <- mutate(OPC_final_surv, 
                         survtime = OS..Calculated.,
                         survind = 1 - Overall.Survival..1.alive..0.dead.)
## remove extraneous variables for analysis
OPC_final_surv <- select(OPC_final_surv, Dummy.ID, rel_vars,survtime,survind)

## Relevel factor variables to yield positive coefficients
OPC_final_surv$white <- factor(OPC_final_surv$white,levels=c("White","Other"))
OPC_final_surv$Gender <- relevel(OPC_final_surv$Gender,"Female")
OPC_final_surv$HPV.P16.status <- relevel(OPC_final_surv$HPV.P16.status,"Unknown")
OPC_final_surv$smoke <- relevel(OPC_final_surv$smoke,"Never")
OPC_final_surv$tumor_subsite <- relevel(OPC_final_surv$tumor_subsite,"BOT")
OPC_final_surv$neck_dissection <- relevel(OPC_final_surv$neck_dissection,"N")
OPC_final_surv$T.category <- factor(OPC_final_surv$T.category)
levels(OPC_final_surv$T.category) <- levels(OPC_final_surv$T.category)[c(4:1)]
OPC_final_surv$N.category <- factor(OPC_final_surv$N.category)
OPC_final_surv$N.category <- relevel(OPC_final_surv$N.category,"N2")

# Cox proportional hazards models - standard covariates
fmla_surv <- as.formula(paste0("Surv(survtime, survind) ~",paste0(rel_vars,collapse="+")))
fit_os <- coxph(fmla_surv, data=OPC_final_surv)

## baseline hazard 
h0_5yr <- max(basehaz(fit_os, centered=FALSE)[basehaz(fit_os)$time<=60,]$haz)
baseline_haz <- exp(-h0_5yr)

### design matrix
design.OPC <- data.frame(t(t(model.matrix(~Gender, data=OPC_final_surv)[,2])),
                         OPC_final_surv$age, 
                         model.matrix(~HPV.P16.status+T.category+N.category+smoke+white, data=OPC_final_surv)[,2:12],
                         OPC_final_surv$pack_year,
                         model.matrix(~tumor_subsite+neck_boost+neck_dissection, data=OPC_final_surv)[,2:5])
## predictions for each participant 
preds_os <- exp(-h0_5yr)^exp((as.matrix(design.OPC))%*%(matrix(fit_os$coefficients)))

## Repeat for progression-free survival outcome
OPC_final_pfs <- OPC_final_clinic
OPC_final_pfs <- mutate(OPC_final_clinic, 
            survtime = pmin(Locoregional.control..Time., FDM..months.),
            survind = ifelse((Locoregional.control..Time. == survtime)*
                (1 - Locoregional.Control.1.Control.0.Failure.) +
                (FDM..months. == survtime)*(1 - Distant.Control..1.no.DM..0.DM.) > 0 , 1, 0))
OPC_final_pfs <- select(OPC_final_pfs, Dummy.ID, rel_vars,survtime,survind)

## Relevel factor variables to yield positive coefficients
OPC_final_pfs$Gender <- relevel(OPC_final_pfs$Gender,"Female")
OPC_final_pfs$white <- relevel(OPC_final_pfs$white,"White")
OPC_final_pfs$HPV.P16.status <- relevel(OPC_final_pfs$HPV.P16.status,"Unknown")
OPC_final_pfs$smoke <- relevel(OPC_final_pfs$smoke,"Never")
OPC_final_pfs$tumor_subsite <- relevel(OPC_final_pfs$tumor_subsite,"Other")
OPC_final_pfs$neck_dissection <- relevel(OPC_final_pfs$neck_dissection,"N")
OPC_final_pfs$T.category <- factor(OPC_final_pfs$T.category)
levels(OPC_final_pfs$T.category) <- levels(OPC_final_pfs$T.category)[c(4:1)]
OPC_final_pfs$N.category <- factor(OPC_final_pfs$N.category)

## fit Cox proportional hazards model
fit_pfs <- coxph(fmla_surv, data=OPC_final_pfs)

## baseline hazard 
h0_5yr_pfs <- max(basehaz(fit_pfs, centered=FALSE)[basehaz(fit_pfs)$time<=60,]$haz)
baseline_haz_pfs <- exp(-h0_5yr_pfs)

### design matrix
design.OPC_pfs <- data.frame(t(t(model.matrix(~Gender, data=OPC_final_pfs)[,2])),
                             OPC_final_pfs$age, 
                             model.matrix(~HPV.P16.status+T.category+N.category+smoke+white, data=OPC_final_pfs)[,2:12],
                             OPC_final_pfs$pack_year,
                             model.matrix(~tumor_subsite+neck_boost+neck_dissection, data=OPC_final_pfs)[,2:5])
## predictions for each participant
preds_pfs <- exp(-h0_5yr_pfs)^exp((as.matrix(design.OPC_pfs))%*%(matrix(fit_pfs$coefficients)))

##########################
##### Compile Output #####
##########################


d_final_preds <- paste0(file.dir, "/Risk_preds.csv")
d_final_weights <- paste0(file.dir, "/Risk_pred_model_coefficients_11_18.csv")

final_preds <- data.frame(ID=OPC_final_clinic$Dummy.ID, 
                          feeding_tube_prob = fit_ft$fitted.values,
                          aspiration_prob = fit_asp$fitted.values,
                          overall_survival_5yr_prob = preds_os,
                          progression_free_5yr_prob = preds_pfs)
write.csv(final_preds, file=d_final_preds)

weights <- list(data.frame(coef=fit_ft$coefficients[-1],var=names(fit_ft$coefficients[-1])),
                data.frame(coef=fit_asp$coefficients[-1],var=names(fit_asp$coefficients[-1])),
                data.frame(coef=fit_os$coefficients,var=names(fit_os$coefficients)),
                data.frame(coef=fit_pfs$coefficients,var=names(fit_pfs$coefficients)))

final_weights <- reduce(weights,full_join,by="var")
colnames(final_weights) <- c("feeding_tube_coef","variable","aspiration_coef",
                             "overall_survival_5y4_coef","progression_free_5yr_coef")
final_weights <- final_weights[order(final_weights$variable),]
final_weights <- final_weights[,c(2,1,3:5)]
rownames(final_weights) <- NULL

write.csv(final_weights, file=d_final_weights)





