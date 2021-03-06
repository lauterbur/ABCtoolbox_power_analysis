#!/bin/bash

# ========================================================================================
# --- Generate simulated datasets under broad uniform distributions
# ========================================================================================

# Number of DNA loci
PARAM_d=$1
# Number of STR loci
PARAM_s=$2
# Number of individuals
PARAM_i=$3

# Initial and final effective population sizes - minimum in uniform distribution
PARAM_N_min=$4
# Initial and final effective population sizes - maximum in uniform distribution
PARAM_N_max=$5
# Time since pop size change - minimum in uniform distribution
PARAM_t_min=$6
# Time since pop size change - minimum in uniform distribution
PARAM_t_max=$7

# Number of simulations to run
NUM_SIMS=$8

# Output directory
OUT_DIR=$9

module load fastsimcoal
module load arlsumstat/3522
module load abctoolbox/2.0

# ----------------------------------------------------------------------------------------
#    # Example:
#    PARAM_d=999; PARAM_s=999; PARAM_i=24;
#    PARAM_N_min=100; PARAM_N_max=10000; PARAM_t_min=80; PARAM_t_max=400
#    NUM_SIMS=100
#    OUT_DIR=results/simulated_data/broad/
# ----------------------------------------------------------------------------------------

mkdir -p $OUT_DIR
cd $OUT_DIR

# Generic name
SAMPLER_INPUT=ABCsampler.input
EST_FILE="DNA_and_STR.est"
PAR_FILE_DNA="DNA_${PARAM_d}_${PARAM_i}.par"
PAR_FILE_STR="STR_${PARAM_s}_${PARAM_i}.par"
ESTIMATOR_INPUT=ABCestimator.input

# --- Transform N into log(N) - Base 10!
PARAM_N_min_log=$(echo "l($PARAM_N_min)/l(10)" | bc -l)
PARAM_N_max_log=$(echo "l($PARAM_N_max)/l(10)" | bc -l)

# ----------------------------------------------------------------------------------------
# --- Write .est file with simulation parameters
# ----------------------------------------------------------------------------------------

echo -e "// Priors and rules file" > $EST_FILE
echo -e "// *********************" >> $EST_FILE
echo -e "" >> $EST_FILE

echo -e "[PARAMETERS]" >> $EST_FILE

echo -e "// All N are in number of diploid individuals" >> $EST_FILE
echo -e "0\tLOG_N_NOW\tunif\t$PARAM_N_min_log\t$PARAM_N_max_log\toutput" >> $EST_FILE
echo -e "0\tLOG_N_ANCESTRAL\tunif\t$PARAM_N_min_log\t$PARAM_N_max_log\toutput" >> $EST_FILE

echo -e "1\tT_SHRINK\tunif\t$PARAM_t_min\t$PARAM_t_max\toutput" >> $EST_FILE

echo -e "0\tSTR_MUTATION\tunif\t0.00001\t0.0001\toutput" >> $EST_FILE
echo -e "0\tMTDNA_MUTATION\tunif\t0.0000001\t0.000001\toutput" >> $EST_FILE
echo -e "0\tGAMMA\tunif\t8\t15\toutput" >> $EST_FILE

echo -e "" >> $EST_FILE

# Add this back in if we ever want to test only pop growths or pop declines
# echo -e "[RULES]" >> $EST_FILE
# echo -e "LOG_N_ANCESTRAL > LOG_N_NOW" >> $EST_FILE
# echo -e "" >> $EST_FILE

echo -e "[COMPLEX PARAMETERS]" >> $EST_FILE
echo -e "1\tN_NOW = pow10( LOG_N_NOW )\toutput" >> $EST_FILE
echo -e "1\tN_ANCESTRAL = pow10( LOG_N_ANCESTRAL )\toutput" >> $EST_FILE
echo -e "0\tN_ANCESTRAL_REL = N_ANCESTRAL / N_NOW\toutput" >> $EST_FILE
echo -e "0\tN_NOW_REL = N_NOW / N_ANCESTRAL\toutput" >> $EST_FILE
echo -e "1\tN_NOW_MTDNA = N_NOW / 4\toutput" >> $EST_FILE
echo -e "" >> $EST_FILE

# ----------------------------------------------------------------------------------------
# --- Write *.par file
# ----------------------------------------------------------------------------------------

echo "//Number of population samples (demes)" > $PAR_FILE_DNA
echo "1" >> $PAR_FILE_DNA
echo "//Population effective sizes (number of genes)" >> $PAR_FILE_DNA
echo "N_NOW" >> $PAR_FILE_DNA
echo "//Sample sizes: 2*N" >> $PAR_FILE_DNA
echo $((PARAM_i * 2)) >> $PAR_FILE_DNA
echo "//Growth rates  : negative growth implies population expansion" >> $PAR_FILE_DNA
echo "0" >> $PAR_FILE_DNA
echo "//Number of migration matrices :" >> $PAR_FILE_DNA
echo "0" >> $PAR_FILE_DNA

echo "//historical event: time, source, sink, migrants, new size, " \
     "new growth rate, migration matrix" >> $PAR_FILE_DNA
echo "1 historical event" >> $PAR_FILE_DNA
echo "T_SHRINK 0 0 0 N_NOW_REL 0 0" >> $PAR_FILE_DNA

cp $PAR_FILE_DNA $PAR_FILE_STR

# --- DNA
echo "//Number of independent loci [chromosome]" >> $PAR_FILE_DNA
echo "$PARAM_d 0" >> $PAR_FILE_DNA
echo "//Per chromosome: Number of linkage blocks" >> $PAR_FILE_DNA
echo "1" >> $PAR_FILE_DNA
echo "//per Block: data type, num loci, rec. rate and mut rate + " \
     "optional parameters" >> $PAR_FILE_DNA
echo "DNA 500 0.00000 0.00000002 0.33" >> $PAR_FILE_DNA

# --- STR
echo "//Number of independent loci [chromosome]" >> $PAR_FILE_STR
echo "$PARAM_s 0" >> $PAR_FILE_STR
echo "//Per chromosome: Number of linkage blocks" >> $PAR_FILE_STR
echo "1" >> $PAR_FILE_STR
echo "//per Block: data type, num loci, rec. rate and mut rate + " \
     "optional parameters" >> $PAR_FILE_STR
echo "MICROSAT 1 0.0000 0.0005 0 0" >> $PAR_FILE_STR

# Test:
# module load fastsimcoal
# module load arlsumstat
# sed -e "s/^TaskNumber=.*/TaskNumber=18499/" $ARLSUMSTAT_DIR/arl_run.ars > arl_run.ars
# cp $ARLSUMSTAT_DIR/ssdefs.modified.txt  ssdefs.txt
# - DNA:
# sed -e "s/N_NOW$/2000/" -e "s/T_SHRINK/100/" -e "s/N_NOW_REL/0.001/" $PAR_FILE_DNA > tmp.par
# fsc25 -i tmp.par -n 1
# arlsumstat tmp/tmp_1_1.arp summary_stats-temp.DNA.txt 0 1
# sh ../../../scripts/add_suffix_to_sumstats.sh summary_stats-temp.DNA.txt DNA
# rm -r tmp/
# rm tmp.par
# rm summary_stats-temp.DNA.txt*
# - STRs:
# sed -e "s/N_NOW$/2000/" -e "s/T_SHRINK/100/" -e "s/N_NOW_REL/0.001/" $PAR_FILE_STR > tmp.par
# fsc25 -i tmp.par -n 1
# arlsumstat tmp/tmp_1_1.arp summary_stats-temp.STR.txt 0 1
# sh ../../../scripts/add_suffix_to_sumstats.sh summary_stats-temp.STR.txt STR
# rm -r tmp/
# rm tmp.par
# rm summary_stats-temp.STR.txt

# ----------------------------------------------------------------------------------------
# --- Create fake placeholder observation file
# --- ABCsampler needs it, even if not used during sampling, to ensure that the
# --- correct summary stats are being generated
# ----------------------------------------------------------------------------------------

# All the summary stats:
# Both: K_1 Ksd_1 mean_K sd_K tot_K H_1 Hsd_1 mean_H sd_H tot_H
# DNA:  S_1 prS_1 mean_S sd_S tot_S D_1 mean_D sd_D FS_1 mean_FS sd_FS Pi_1 mean_Pi sd_Pi
# STR:  GW_1 GWsd_1 mean_GW sd_GW tot_GW NGW_1 NGWsd_1 mean_NGW sd_NGW R_1 Rsd_1 mean_R sd_R tot_R

# Common to both DNA and STRs
echo -ne "K_1\tKsd_1\tmean_K\tsd_K\ttot_K\t" \
         "H_1\tHsd_1\tmean_H\tsd_H\ttot_H\t" | sed -e "s/ //g" > fake_DNA.obs
cp fake_DNA.obs fake_STR.obs

# DNA specific ones
echo -ne "S_1\tprS_1\tmean_S\tsd_S\ttot_S\tD_1\tmean_D\tsd_D\tFS_1\tmean_FS\t" \
         "sd_FS\tPi_1\tmean_Pi\tsd_Pi\n" | sed -e "s/ //g" >> fake_DNA.obs

for i in `seq 1 23`; do
    echo -ne "0.1\t" >> fake_DNA.obs
done
echo -ne "0.1\n" >> fake_DNA.obs

# STR specific ones
echo -ne "GW_1\tGWsd_1\tmean_GW\tsd_GW\ttot_GW\tNGW_1\tNGWsd_1\tmean_NGW\t" \
         "sd_NGW\tR_1\tRsd_1\tmean_R\tsd_R\ttot_R\n" | sed -e "s/ //g" >> fake_STR.obs

for i in `seq 1 23`; do
    echo -ne "0.1\t" >> fake_STR.obs
done
echo -ne "0.1\n" >> fake_STR.obs

sh ../../../scripts/add_suffix_to_sumstats.sh fake_DNA.obs DNA
sh ../../../scripts/add_suffix_to_sumstats.sh fake_STR.obs STR

# Add suffix to last sum stat. Program ignores it because it doesn't end in a tab.
sed -i".bak" -e "1s/$/_DNA/" fake_DNA.obs
sed -i".bak" -e "1s/$/_STR/" fake_STR.obs

# ----------------------------------------------------------------------------------------
# --- Write ABCsampler input file
# ----------------------------------------------------------------------------------------

echo "samplerType standard" > $SAMPLER_INPUT
echo "estName $EST_FILE" >> $SAMPLER_INPUT
echo "obsName fake_DNA.obs;fake_STR.obs" >> $SAMPLER_INPUT
echo "outName ABCsampler_output_DNA${PARAM_d}_STR${PARAM_s}_IND${PARAM_i}" >> $SAMPLER_INPUT
echo "separateOutputFiles 0" >> $SAMPLER_INPUT
echo "numSims $NUM_SIMS" >> $SAMPLER_INPUT
echo "writeHeader 1" >> $SAMPLER_INPUT
echo "simProgram fsc25;fsc25" >> $SAMPLER_INPUT
echo "simInputName ${PAR_FILE_DNA};${PAR_FILE_STR}" >> $SAMPLER_INPUT
#echo "simParam -i#SIMINPUTNAME#-n#1;-i#SIMINPUTNAME#-n#1" >> $SAMPLER_INPUT
echo "simArgs -i ${PAR_FILE_DNA/.par/-temp.par} -n1;-i ${PAR_FILE_STR/.par/-temp.par} -n1" >> $SAMPLER_INPUT
##echo "simParam -i#${PAR_FILE_DNA}#-n#1;-i#${PAR_FILE_STR}#-n#1" >> $SAMPLER_INPUT
##echo "simParam -i#${PAR_FILE_DNA}#-n#1" >> $SAMPLER_INPUT
echo "sumStatProgram arlsumstat;arlsumstat" >> $SAMPLER_INPUT
###echo "sumStatParam SIMDATANAME#SSFILENAME#0#1" >> $SAMPLER_INPUT
echo "simDataName ${PAR_FILE_DNA/.par/-temp.par};${PAR_FILE_STR/.par/-temp.par}" >> $SAMPLER_INPUT
#       arlsumstat $ARP                                                        $OUT          0 1
#echo "sumStatArgs ${PAR_FILE_DNA/.par}-temp/${PAR_FILE_DNA/.par}-temp_1_1.arp ${PAR_FILE_DNA/.par/-temp.par} 0 1;${PAR_FILE_STR/.par}-temp/${PAR_FILE_STR/.par}-temp_1_1.arp ${PAR_FILE_STR/.par/-temp.par} 0 1" >> $SAMPLER_INPUT
echo "sumStatArgs ${PAR_FILE_DNA/.par}-temp/${PAR_FILE_DNA/.par}-temp_1_1.arp summary_stats-temp.DNA.txt 0 1;${PAR_FILE_STR/.par}-temp/${PAR_FILE_STR/.par}-temp_1_1.arp summary_stats-temp.STR.txt 0 1" >> $SAMPLER_INPUT
echo "sumStatName summary_stats-temp.DNA.txt;summary_stats-temp.STR.txt" >> $SAMPLER_INPUT
echo "scriptAfterSS ../../../scripts/add_suffix_to_sumstats.sh;../../../scripts/add_suffix_to_sumstats.sh" >> $SAMPLER_INPUT
echo "scriptAfterSSArgs summary_stats-temp.DNA.txt DNA;summary_stats-temp.STR.txt STR" >> $SAMPLER_INPUT
echo "executionErrors warn" >> $SAMPLER_INPUT
echo "task simulate" >> $SAMPLER_INPUT
echo "verbose" >> $SAMPLER_INPUT

#cp $ARLSUMSTAT_DIR/arl_run.modified.ars arl_run.ars
# Now with more Tajima's D and Fu's FS
sed -e "s/^TaskNumber=.*/TaskNumber=18499/" $ARLSUMSTAT_DIR/arl_run.ars > arl_run.ars
cp $ARLSUMSTAT_DIR/ssdefs.modified.txt  ssdefs.txt

ln -s `which fsc25` fsc25
ln -s `which arlsumstat` arlsumstat

ABCtoolbox $SAMPLER_INPUT

# Results in ABCsampler_output_DNA*_STR*_IND*_sampling1.txt
