#!/usr/bin/env bash
# -*- encoding: utf-8 -*-
'''
@File    :   trimmomatic.sh
@Time    :   2022/12/04
@Author  :   Zhou Lab 
@Version :   1.0
@Contact :    https://github.com/zhouyflab
@License :   (C)Copyright 2021-2022, CAAS ShenZhen
@Desc    :   To annotate the genome 
'''

java -jar trimmomatic-0.38.jar PE -threads 16 ILLUMINACLIP:$dirname/Trimmomatic-0.38/adapters/TruSeq3-PE-2.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:50 TOPHRED33