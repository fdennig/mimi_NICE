using Mimi

@defcomp sealevelrise begin
    regions = Index()

    SLRTHERM = Variable(index=[time])
    THERMEQUIL = Variable(index=[time])
    GSICREMAIN = Variable(index=[time])
    GSICCUM = Variable(index=[time])
    GSICMELTRATE = Variable(index=[time])
    GISREMAIN = Variable(index=[time])
    GISMELTRATE = Variable(index=[time])
    GISEXPONENT = Variable(index=[time])
    GISCUM = Variable(index=[time])
    AISREMAIN = Variable(index=[time])
    AISMELTRATE = Variable(index=[time])
    AISCUM = Variable(index=[time])
    TOTALSLR = Variable(index=[time])

    TATM = Parameter(index=[time])
    thermeq = Parameter()
    therm0 = Parameter()
    thermadj = Parameter()
    gsictotal = Parameter()
    gsicmelt = Parameter()
    gsicexp = Parameter()
    gis0 = Parameter()
    gismelt0 = Parameter()
    gismeltabove = Parameter()
    gismineq = Parameter()
    gisexp = Parameter()
    aismelt0 = Parameter()
    aismeltlow = Parameter()
    aismeltup = Parameter()
    aisratio = Parameter()
    aisinflection = Parameter()
    aisintercept = Parameter()
    aiswais = Parameter()
    aisother = Parameter()

    # Run in full compatability mode with the Excel version
    fullExcelCompat::Bool = Parameter()
end

function run_timestep(state::sealevelrise, t::Int)
    v, p, d = getvpd(state)

#THERMAL EXPANSION

    #Define function for THERMEQUIL
    v.THERMEQUIL[t] = p.TATM[t] * p.thermeq

    #Define function for SLRTHERM
    if t==1
        v.SLRTHERM[t] = p.therm0 + p.thermadj * (v.THERMEQUIL[t] - p.therm0)
    else
        v.SLRTHERM[t] = v.SLRTHERM[t-1] + p.thermadj * (v.THERMEQUIL[t] - v.SLRTHERM[t-1])
    end

#GLACIERS AND SMALL ICE CAPS (GSIC)

    #Define function for GSICREMAIN
    if t == 1
        v.GSICREMAIN[t] = p.gsictotal
    else
        v.GSICREMAIN[t] = p.gsictotal - v.GSICCUM[t-1]
    end

    #Define function for GSICMELTRATE
    if t == 1
        v.GSICMELTRATE[t] = 0.01464  # #Bug in Excel Model?  gsiceq parameter drops out after first period (this is replicated here by just setting period 1 and exluding gsiceq from equation)
    else
        v.GSICMELTRATE[t] = p.gsicmelt * 10 * (v.GSICREMAIN[t] / p.gsictotal)^(p.gsicexp) * p.TATM[t]
    end

    #Define function for GSICCUM
    if t == 1
        v.GSICCUM[t] = v.GSICMELTRATE[t]
    else
        v.GSICCUM[t] = v.GSICCUM[t-1] + v.GSICMELTRATE[t]
    end

#GREENLAND ICE SHEETS (GIS)

    #Define function for GISREMAIN
    if t == 1
        v.GISREMAIN[t] = p.gis0
    else
        v.GISREMAIN[t] = v.GISREMAIN[t-1] - v.GISMELTRATE[t-1] / 100
    end

    #Define function for GISMELTRATE
    if t == 1 || t == 2
        v.GISMELTRATE[t] = p.gismelt0
    else
        v.GISMELTRATE[t] = (p.gismeltabove * (p.TATM[t] - p.gismineq) + p.gismelt0) * v.GISEXPONENT[t-1]
    end

    #Define function for GISCUM
    if t == 1
        v.GISCUM[t] = p.gismelt0 / 100
    else
        v.GISCUM[t] = v.GISCUM[t-1] + v.GISMELTRATE[t] / 100
    end

    #Define function for GISEXPONENT
    if t ==1 || t == 2
        v.GISEXPONENT[t] = 1.
    else
        v.GISEXPONENT[t] = 1. - (v.GISCUM[t] / p.gis0)^p.gisexp
    end

#ANTARCTIC ICE SHEET (AIS)

    #Define function for AISMELTRATE
    if t <= 11
    v.AISMELTRATE[t] = ifelse(p.TATM[t] < 3., (p.aismeltlow * p.TATM[t] * p.aisratio + p.aisintercept), (p.aisinflection * p.aismeltlow + p.aismeltup * (p.TATM[t] - 3.) + p.aisintercept))
    else
    v.AISMELTRATE[t] = ifelse(p.TATM[t] < 3., (p.aismeltlow * p.TATM[t] * p.aisratio + p.aisintercept), (p.aisinflection * p.aismeltlow + p.aismeltup * (p.TATM[t] - 3.) + p.aismelt0))
    end

    #Define function for AISCUM
    if t == 1
        v.AISCUM[t] = v.AISMELTRATE[t] / 100
    else
        v.AISCUM[t] = v.AISCUM[t-1] + v.AISMELTRATE[t] / 100
    end

    #Define function for AISREMAIN
    if t == 1
        v.AISREMAIN[t] = p.aiswais + p.aisother
    else
        v.AISREMAIN[t] = v.AISREMAIN[1] - v.AISCUM[t]
    end

#TOTAL SEA LEVEL RISE AND DAMAGES

    #Define function for TOTALSLR
    v.TOTALSLR[t] = v.SLRTHERM[t] + v.GSICCUM[t] + v.GISCUM[t] + v.AISCUM[t]

end
