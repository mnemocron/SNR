"""

https://github.com/hrtlacek/SNR

- Method 3 uses the FFT to analyse for a fundamental frequency.
  It assumes that the input is a sinusoidal signal, the system adds noise and 
  can contain weak non-linearities.

"""

import numpy as np
import scipy.signal as sig
import copy
import sys 

def bandpower(ps, mode='psd'):
    """
    estimate bandpower, see https://de.mathworks.com/help/signal/ref/bandpower.html
    """
    if mode=='time':
        x = ps
        l2norm = np.linalg.norm(x)**2./len(x)
        return l2norm
    elif mode == 'psd':
        return sum(ps)      

def getIndizesAroundPeak(arr, peakIndex,searchWidth=1000):
    peakBins = []
    magMax = arr[peakIndex]
    curVal = magMax
    for i in range(searchWidth):
        newBin = peakIndex+i
        if(newBin>=len(arr)):
            break
        newVal = arr[newBin]
        if newVal>curVal:
            break
        else:
            peakBins.append(int(newBin))
            curVal=newVal
    curVal = magMax
    for i in range(searchWidth):
        newBin = peakIndex-i
        if(newBin<0):
            break
        newVal = arr[newBin]
        if newVal>curVal:
            break
        else:
            peakBins.append(int(newBin))
            curVal=newVal
    return np.array(list(set(peakBins)))

def freqToBin(fAxis, Freq):
    return np.argmin(abs(fAxis-Freq))

def getPeakInArea(psd, faxis, estimation, searchWidthHz = 10):
    """
    returns bin and frequency of the maximum in an area
    """
    binLow = freqToBin(faxis, estimation-searchWidthHz)
    binHi = freqToBin(faxis, estimation+searchWidthHz)
    if(binLow == binHi):
        if(binLow > 0):
            binLow -= 1
        elif(binHi+1 < len(faxis)):
            binHi += 1
    peakbin = binLow + np.argmax(psd[binLow:binHi])
    return peakbin, faxis[peakbin]

def getHarmonics(fund,sr,nHarmonics=6,aliased=False):
    harmonicMultipliers = np.arange(2,nHarmonics+2)
    harmonicFs = fund * harmonicMultipliers
    if not aliased:
        harmonicFs[harmonicFs>sr/2] = -1
        harmonicFs = np.delete(harmonicFs,harmonicFs==-1)
    else:
        nyqZone = np.floor(harmonicFs/(sr/2))
        oddEvenNyq = nyqZone%2  
        harmonicFs = np.mod(harmonicFs,sr/2)
        harmonicFs[oddEvenNyq==1] = (sr/2)-harmonicFs[oddEvenNyq==1]
    return harmonicFs   

def calc_snr(x):
    sr = 1 # normalize sample rate (SNR should not depend on it and is treated as unknown)
    faxis,ps = sig.periodogram(x,fs=sr, window=('kaiser',38)) #get periodogram, parametrized like in matlab
    fundBin = np.argmax(ps) #estimate fundamental at maximum amplitude, get the bin number
    fundIndizes = getIndizesAroundPeak(ps,fundBin) #get bin numbers around fundamental peak
    fundFrequency = faxis[fundBin] #frequency of fundamental
    nHarmonics = 6
    harmonicFs = getHarmonics(fundFrequency,sr,nHarmonics=nHarmonics,aliased=True) #get harmonic frequencies
    harmonicBorders = np.zeros([2,nHarmonics],dtype='int16').T
    fullHarmonicBins = np.array([], dtype='int16')
    fullHarmonicBinList = []
    harmPeakFreqs=[]
    harmPeaks=[]
    for i,harmonic in enumerate(harmonicFs):
        searcharea = 0.1*fundFrequency
        estimation = harmonic
        binNum, freq = getPeakInArea(ps,faxis,estimation,searcharea)
        harmPeakFreqs.append(freq)
        harmPeaks.append(ps[binNum])
        allBins = getIndizesAroundPeak(ps, binNum,searchWidth=1000)
        fullHarmonicBins=np.append(fullHarmonicBins,allBins)
        fullHarmonicBinList.append(allBins)
        harmonicBorders[i,:] = [allBins[0], allBins[-1]]
    fundIndizes.sort()
    pFund = bandpower(ps[fundIndizes[0]:fundIndizes[-1]]) #get power of fundamental 
    fundRemoved = np.delete(ps,fundIndizes) #remove the fundamental (start constructing the noise-only signal)
    fAxisFundRemoved = np.delete(faxis,fundIndizes)
    noisePrepared = copy.copy(ps)
    noisePrepared[fundIndizes] = 0
    noisePrepared[fullHarmonicBins] = 0
    noiseMean = np.median(noisePrepared[noisePrepared!=0])
    noisePrepared[fundIndizes] = noiseMean 
    noisePrepared[fullHarmonicBins] = noiseMean
    noisePower = bandpower(noisePrepared)
    r = 10*np.log10(pFund/noisePower)
    return r

#%%
if __name__ == "__main__":
    n = len(sys.argv)
    if(n < 2):
        print('error: no file provided')
        exit(-1)
        
    filename = sys.argv[1]
    if ('--help' in filename):
        print('snr.py')
        print('Usage:')
        print('\tsnr <filename>\tcalculates SNR on values in <filename>')
        exit(0)
    
    with open(filename, 'r') as file:
        lines = file.readlines()
    signed_integers = np.array([int(line.strip(), 2) for line in lines], dtype=np.int32)
    bit_length = sum(c.isdigit() for c in lines[0])
    signed_integers[signed_integers >= 2**(bit_length - 1)] -= 2**bit_length
    snr = calc_snr(signed_integers)
    print(f'{snr:.1f}')
    exit(0)

