/*==================================================
              0: Program set up
==================================================*/
clear all
global data ../../data
global results ../../results/Distributions

/* This file runs the analysis needed to predict the entire distribution using 100 quantiles and their associated poverty lines to predict poverty headcounts*/


/* 3_Do files: predictions using different methods*/

do 3_Distributions_GDP.do // this file uses GDP and fisk, lognormal, frac logit

do 3_Distributions_GNI.do // this file uses GNI and fisk, lognormal, frac logit

do 3_Distributions_HFCE.do // this file uses HFCE and fisk, lognormal, frac logit

/* 4_Do files: merge different methods*/
do 4_CompareMethods

/* 5_Do files: Estimate Loss function*/
do 4_LossFunction.do

