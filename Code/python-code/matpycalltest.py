# -*- coding: utf-8 -*-
"""
Created on Sat Feb 21 13:55:24 2026

@author: Brian
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.signal import butter, filtfilt
from scipy.stats import linregress
from scipy.optimize import curve_fit
import scipy
from github_code_ipshita.tools.data_import import import_ppd, preprocess_data
from pathlib import Path

print(os.getcwd())
