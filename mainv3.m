% all times are in ms
lag = 20; % accounts for ability delay. must be above 0.

%raid debuffs
%marked = 0.05; % 5% from ranged attacks
%susceptible = 0.05; % 5% from tech attacks
%beatdown = 0.05; % 5% from melee attacks
vulnerable = 0.05; % 5% from force attacks
assailable = 0.07; % 7% from I/E attacks
overwhelmed = 0.1; % 10% from aoe attacks
sundered = 0.2; % 20% reduced armor rating

boss_defense = 0.1;
boss_armor = 8829 * (1-sundered);
boss_DR = boss_armor / ( boss_armor + 240*60 + 800);
bossHP = 1000000;
bossHP30 = bossHP*0.7; % used for execute talent
sh = 3185; % standard health

[bonusDmgBuff, mainStatBuff, critBuff] = deal(0.05); % class buffs
stim1 = 198; % main stat
stim2 = 81; % power

%which spec
telekinetics = 1; 
balance = ~telekinetics;

forceSuppression = balance; % 10% to next 15 dots - OK
presenceOfMind = balance; %presence of mind proc - OK
criticalKinesis = balance*0.05; % 5% to crit of Disturbance and Serenity - OK
drainThoughts = balance*0.1; % 10% dmg to all periodic effects - OK
ripplingForce = balance; % rippling force proc, 20% chance from tkt and 60% from Force Serenity, restores 2 force - OK
mindWarp = balance; % adds 2 ticks to MC and Vanquish - OK
mentalScarring = balance; % 15% dot damage on targets under 30% hp and Force Serenity restores 15 Force when used on target with Force Suppression - OK
pP = balance; % Psychic Projection tkt channels 33% faster, but does 25% less dmg - OK
mindsEye = balance; % Serenity does 25% more damage on target affected with weaken mind. eating supression stacks returns 2 force - OK

mentalMomentum = telekinetics*0.3; %MC has 30% chance to tick twice, makes target vulnerable, Turbulence has 30% chance to get 2nd blast for 30% damage
telekineticMomentum = telekinetics*0.3; %Disturbance, TK Wave, TK Gust and TK Burst have 30% chance for second burst dealing 30% damage - OK
flowingForce = telekinetics; %Telekinetic Momentum is twice as likely to trigger under Mental Alacrity. Increases MA duration by 5 seconds and reduces its cd by 15 seconds - OK
telekineticFocalPoint=telekinetics*0.5; %TK Wave and TK Gust have 50% chance to add stack of Focal Telekinetics - OK
tremors = telekinetics; %Each TK and Mental Momentum reduce active cd of MA by 1 second - OK
reverberation = telekinetics*0.3; %Critical multiplier of TK Wave, MC, Turbulence and TK Gust up by 30% - OK
mentalContinuum = telekinetics; %Direct damage from MC and TK Wave refreshes weaken mind on targets, TK Burst boosts force regen by 10%, stacks 3 times, lasts 10 seconds. - OK

relic1 = 0; %boundless ages
relic2 = 1; %focused retribution
relic3 = 1; %serendipitous assault
relic4 = 0; %damage proc relic
setbonus1 = 1; % 2% fm buff
setbonus2 = 1; % 15 seconds off MA, 2 cost off tkt and Disturbance
setbonus3 = 1; % Disturbance and TK Burst reduce cd of Potency by 1 second.
adrenal = 750; %685 for blues, 675 for old blues, 625 for old purples
powerrelic = 560;
procrelic = 890;

%simulation is not rounding force costs or force itself, not sure whether or not game does in backend
forcePool = 600;
innerStrength = 0.1;
mccost = 40 * (1-innerStrength);
sfcost = 20 * (1-innerStrength);
wmcost = 35 * (1-innerStrength);
tktcost = 30 * (1-innerStrength)-setbonus2*2;
distcost = 40 * (1-innerStrength)-setbonus2*2;
fibcost = 50 * (1-innerStrength);
vqcost = 30 * (1-innerStrength);
srcost = 40 * (1-innerStrength);
tucost=50 * (1-innerStrength);
twcost=50 * (1-innerStrength);
tgcost=50 * (1-innerStrength);
tbcost=30 * (1-innerStrength);

%starting stats - got best results with these and full wp augs
mainStatBase0 = 240*12 + 550; % 3430 - mainstat from armorings and mods; before class buff - OK
powerBase0 = 12*90 + 2*41 + 2*52 + 9*81; % 1266 - power from enhancements, crystals and relics. 1995 with 9 power enhancements
forcepowerBase = 1395*2;
accuracyBase = 720;
criticalBase = 81;
alacrityBase = 240;
surgBase = 240;
bonusDmg = 0; %calculated later

tic
dpsinc=zeros(100,9); %[mainStatBase, powerBase, criticalBase, accuracyBase alacrityBase, surgBase, mindps meandps maxdps]
istat=1; %outer loop counter
iterations=1000; % inner loop iterations

disp('       mainstat       power         crit         acc          alac         surge     mindps       meandps      maxdps ')
for iaug=0:2    
    mainStatBase=mainStatBase0+iaug*52*7;
    powerBase=powerBase0+(14-iaug*7)*52;
    dps = zeros(iterations,2);

    parfor j=1:iterations

        keytimes = 1000000*ones(2,35);
        totaldmg=0;
        % keytimes is a matrix of time points when something happens;
        % ability ticks, ability cooldowns, force regen etc. 
        % top row are the time points themselves, 
        % bottom onews are numbers representing abilities

        %initializing some variables
        [t, pom, POM, pomdots, cd_mc, cd_sf, cd_wm, cd_fib, cd_fp, cd_ma, cd_ad, cd_ad2, cd_re, cd_pp, cd_pd, cd_fma, cd_vq, cd_sr, cd_tg, cd_tg2, cd_tb, cd_tu, cd_tw, cd_fm, cd_fe, cd_mp, cd_tf, cd_fs] = deal(0);
        [ma, fe, ad, re, wm, vq, sf, sr, fib, dist, tkt, fp, mc, tb, tg, tw, fs, tkb, potent_tkt, potent_fib] = deal(0);

        supp = 0; %force suppression stacks, checks are only supp>0
        damage = 0; %damage unit
        heal = 0; %heal unit
        force = forcePool; %energy unit
        ripforce = 0; % rippling force virtual stacks
        tkfp = 0; % telekinetic focal point stacks
        tkfpstack = 0; % telekinetic focal point stacks check
        potency = 0; % force potency stacks, can go into negative numbers
        malac = 0; % mental alacrity flag
        adrenalOn = 0; % adrenal flag
        powerrelicOn = 0; %boundless ages relic flag
        execute = 0; %for dot increase under 30% hp in Balance
        FM = 0; % 2pc force master flag
        ForceEmpowerment = 0;
        TF = 0; %tidal force flag
        tkEff = 0; %telekinetic effussion stacks, can go into negative
        mM = 0; %mental momentum flag for mind crush
        mcont = 0; % mental continuum force regen stacks
        mcontstack = 0; % mental continuum force regen stacks check
        cf = 0; % clamoring force stacks, can go negative
        
        power = powerBase;
        forcepower = forcepowerBase;
        accuracy = accuracyBase;
        critical = criticalBase;
        alacrity = alacrityBase;
        surg = surgBase;
        abilityDmg = zeros(1,26);
        
        mainStat = (mainStatBase + stim1)*(mainStatBuff + 1);
        Power = (power + stim2 + forcepower);

        acc = 0.3*(1-(1-(1/30)).^(accuracy/60/1.2)) + 0.01; % 1% from companions
        alacbase = 0.3*(1-(1-(1/30)).^(alacrity/60/1.25));
        crit = 0.3*(1-(1-(1/30)).^(critical/60/0.9)) + 0.2*(1-(1-(1/20)).^(mainStat/60/5.5)) + critBuff + 0.05; % 5 % base crit
        surge = 0.3*(1-(1-(1/30)).^(surg/60/0.22)) + 0.51; % +51 % base

        bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
        
        alac = alacbase;
        wmalac = alac;
        gcd = 1500/(1+alac);
        gcdm = 1500/(1+alac+0.2); % used for opener
        
        % OPENER
        if balance==1
            keytimes(:,1:10)=[lag/2 lag lag  1000   gcd+2*lag 2*gcd+3*lag 2*gcd+3*lag 2*gcd+3*lag 2*gcd+3*lag 2*gcd+3*lag;
                              0     3   7   -2      9         18          19          20          21          -1          ];
        else
            keytimes(:,1:9)=[lag/2 lag 2*lag 1000 2*lag+gcd 2*lag+gcd 2*lag+gcd 2*lag+gcd+gcdm 3*lag+gcd+gcdm;
                             0     5   9     -2   19        20        32        27             -1          ];
        %                    stats WM  MC   regen mentalac  adrenal   empower   turbulence     rotation check
        end
        % fun part
        i = 1;
        log = zeros(4,2000);
         while t<420000 && i<2000
            t = keytimes(1,1); % set time
            action = keytimes(2,1);
            keytimes = [keytimes(:,2:end),[1000000; 1000000]]; %deletes first one, shifts others 1 place left, inserts placeholder on last spot
            
            switch action
                case -2 % natural energy regen each second
                    force = min(forcePool, force + 8*(1+alac)*(1+mcont/10)); %min(600, x+regen) so it can't overflow
                    T=t+1000;
                    Tspot = find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; -2], keytimes(:,Tspot:end-1)]; %inserts next regen event in schedule                    
                    damage = 0; % checked later, if damage > 0, relic can proc
                    heal = 0; %same as above
                case -1 % decides about next ability to use
                    damage = 0;
                    heal=0;
                    
                    ma = (cd_ma<=t) * 42; % mental alacrity
                    fe = (cd_fe<=t) * 36; % force empowerment 
                    ad = (cd_ad<=t) * 33; % adrenal
                    re = (cd_re<=t) * 30 * relic1; % boundless ages relic
                    
                    if balance>0 % not finished, it's basically a 2.0 rotation with serenity
                        potent_fib = (potency>0) * 28 * (cd_fib<t) * balance; % with force potency up
                        vq = (cd_vq<=t) * (10+POM*10) * (force >= vqcost); % 0 if on cd, 10 if no presence of mind, 20 if presence of mind
                        sf = (cd_sf<=t) * 18 * (force >= sfcost);
                        wm = (cd_wm<t) * 16 * (force >= wmcost);                    
                        sr = (cd_sr<=t) * 15 * (force >= wmcost);
                        fib = (cd_fib<=t) * 14 * (force >= fibcost);
                        dist = (POM==1 && cd_vq > 3) * 12 * (force >= 100); % if vanquish is on cd for 3+ seconds
                        tkt = 8 * (force >= 24);
                    else
                        fp = (cd_fp<=t) * 39 * (cd_tg<(t+gcd)) * (TF>0); % force potency
                        tb = (cd_tu<=t) * 20 * (force >= tucost*(1-0.75*(tkEff>0))); % turbulence
                        mc = (cd_mc<=t) * 18 * (force >= mccost*(1-0.75*(tkEff>0))) * (cd_tg2>t); %mind crush, last part is about the proc that makes it 0.5s faster
                        tg = (cd_tg<=t) * (15 + (potency>0)*10) * (force >= tgcost*(1-0.75*(tkEff>0))); % telekinetic gust
                        tw = (cd_tw<=t) * (6 + (potency>0)*6) * (force >= twcost*(1-TF/2)*(1-0.75*(tkEff>0))) * (TF + 1) * (cd_fp>t); %tk wave - it's 12 if tidal force is up, otherwise tkburst is always above. if potency is available it'll delay tk wave. if potency is up it's on top of priority
                        fs = (cd_fs<=t) * 11 * (((cd_ad2-t)<gcd) && (cd_ad2>t+lag)); %if adrenal is about to end before casted tk burst would hit target, do force speed
                        tkb = 10 * (force >= tbcost*(1-0.75*(tkEff>0))); % tk burst
                    end
                    nothing = 1; % in case energy is too low

                    gcd = 1500/(1+alac);
                    TKT = (3000-1000*pP)/(1+alac) + lag; %tkt duration in balance
                    MC = (2000-500*(cd_tg>t))/(1+alac); % mind crush activation time
                    VQ = (2000*(1-POM))/(1+alac); % vanquish activation time - 0 with presence of mind
                    VQ2 = (2000*(1-POM/4))/(1+alac); % how long vanquish ability takes, 2 seconds without presence of mind, 1.5 with it
                    TKB = gcd*(cf<=0); % telekinetic burst cast time - 0 if clamoring force (force speed proc)
                    
                    %       1                2        3     4 5      6 7   8 9   10 11  12   13  14 15 16 17 18 19 20 21 22         23         24 25 26 27      28      29      30      31 32 33 34 35 36 37 38 39 40 41
                    A= [    nothing          sr      vq     0 mc     0 sf  0 wm  0  fib dist tkt 0  0  0  0  fp ma ad re potent_fib potent_tkt 0  0  0  tb      tg      tw      tkb     0  fe 0  0  0  0  0  0  0  0  fs];
                    B= t + [1020-mod(t,1000) gcd+lag VQ+lag 0 MC+lag 0 gcd 0 gcd 0  gcd gcd  TKT 0  0  0  0  0  0  0  0  gcd        TKT        0  0  0  gcd+lag gcd+lag gcd+lag gcd+lag 0  0  0  0  0  0  0  0  0  0  0]; % cast times
                    C= t + [0                gcd     VQ2    0 MC     0 lag 0 lag 0  lag lag  lag 0  0  0  0  0  0  0  0  lag        lag        0  0  0  gcd     lag     lag     TKB     0  0  0  0  0  0  0  0  0  0  0]; % schedule ability
                    a=find(A==max(A)); % position of the ability with highest priority
          
                    Tspot=find(C(a)<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [C(a); a], keytimes(:,Tspot:end-1)]; %schedules chosen ability
                    
                    Tspot=find(B(a)<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [B(a); -1], keytimes(:,Tspot:end-1)]; %schedules next rotation check
                    
                case 0 % recalculates ability damage according to stats
                    dmg_mindCrush = (1.23*bonusDmg + sh*[0.103, 0.143]) * (1-boss_DR); 
                    dmg_telekineticthrow = (0.765*bonusDmg + 0.0765*sh) * (1-boss_DR); 
                    dmg_forceinbalance = 1.81*bonusDmg + sh*[0.161, 0.201]; 
                    dmg_disturbance = (1.5*bonusDmg + sh*[0.13, 0.17]) * (1-boss_DR); 
                    dmg_turbulence = 1.8*bonusDmg + sh*[0.16, 0.2];
                    dmg_telekineticwave = (2.14*bonusDmg + sh*[0.194, 0.234]) * (1-boss_DR);
                    dmg_project = (1.49*bonusDmg + sh*[0.129, 0.169]) * (1-boss_DR);
                    dmg_vanquish = (1.295*bonusDmg + sh*[0.1109, 0.149]) * (1-boss_DR);
                    dmg_forceSerenity = 1.74*bonusDmg + sh*[0.154, 0.194];
                    dmg_telekineticgust = (1.96*bonusDmg + sh*[0.176, 0.216]) * (1-boss_DR);
                    dmg_telekineticburst = (1.565*bonusDmg + sh*[0.137, 0.177]) * (1-boss_DR);

                    %dots
                    dmg_severForce = 0.36*bonusDmg + 0.036*sh;
                    dmg_mindCrushDots = (0.295*bonusDmg + 0.0295*sh) * (1-boss_DR);
                    dmg_weakenMind = 0.32*bonusDmg + 0.032*sh;
                    dmg_vanquishDots = (0.35*bonusDmg + sh*0.035) * (1-boss_DR);
                    dmg_ripplingForce = (0.27*bonusDmg + 0.027*sh) * (1-boss_DR); % correct // not considered a dot 

                    abilityDmg = round([dmg_mindCrush, dmg_mindCrushDots, dmg_severForce, dmg_weakenMind, dmg_forceinbalance, dmg_disturbance, dmg_telekineticthrow, dmg_ripplingForce, dmg_telekineticwave, dmg_turbulence, dmg_project, dmg_vanquish, dmg_forceSerenity, dmg_telekineticgust, dmg_telekineticburst, dmg_vanquishDots]);
                    damage = 0;
                    heal = 0;
                case 1 % no energy, wait for regen / deleted weaken mind tick
                    damage = 0;
                    heal = 0;
                case 2 % force serenity    
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(20:21)) * (1 + (-rand + crit + criticalKinesis > 0)*surge) * (1 + (t<cd_wm)*mindsEye*0.25) * (1 + vulnerable + assailable + FM);
                    cd_sr = t+12000/(1+alac);
                    force = force - srcost;
                    if damage > 0
                        if (rand < ripplingForce*0.6)
                            ripforce = ripforce + 1;
                            T=t+1000/(1+alac); % haven't checked that the time it takes for rippling force to tick is affected by alacrity, but it doesn't matter much
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 15], keytimes(:,Tspot:end-1)];  
                        end
                        if supp >0
                            force = min(600, force + 15*mentalScarring);
                        end
                        if cd_fm<t && setbonus1==1
                            FM = 0.02;
                            T=t+15000;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 31], keytimes(:,Tspot:end-1)];
                            cd_fm = t+30000/(1+alac);
                        end
                    end
                    heal = damage;
                case 3 % vanquish
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(18:19)) * (1 + (-rand + crit > 0)*surge) * (FM + vulnerable + POM*0.2 + 1);
                    cd_vq = t+15000/(1+alac);
                    cd_mc = cd_vq;
                    force = force - vqcost*((-(POM==1)+2)/2); % force cost is halved if it was used with Presence of Mind
                    if damage>0
                        if POM==1 % presence of mind is exhausted after initial hit, but dots in game are still affected by it, so this variable makes sure that happens
                            pomdots = 6 + 2*mindWarp;
                            pom=0;
                            POM=0;
                        end
                        T=t+(1000:1000:(6000+1000*mindWarp))/(1+alac);
                        for Tt=T
                            Tspot=find(Tt<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [Tt; 6], keytimes(:,Tspot:end-1)];                    
                        end
                    end
                    heal=0;
                case 4 % vanquish tick
                    damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(26) * (1 + (-rand + crit > 0)*surge) * (1 + drainThoughts + (pomdots>0)*0.2 + FM + vulnerable) * ((supp>0)*0.1 + 1) * (1 + execute);
                    pomdots = pomdots-1;
                    force = min(600, force + 2*mindsEye * (supp>0));
                    if damage>0
                        supp = supp-1; % force suppression
                    end
                    heal=0;
                case 5 % mind crush
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(1:2)) * (1 + (-rand + crit + 0.6*(potency>0) > 0)*(surge + reverberation)) * (FM + vulnerable + 1);
                    cd_mc = t+15000/(1+alac);
                    cd_vq = cd_mc;
                    force = force - mccost*(1-0.75*(tkEff>0));
                    if damage>0
                        T=t+(1000:1000:(6000+1000*mindWarp))/(1+alac);
                        for Tt=T
                            Tspot=find(Tt<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [Tt; 6], keytimes(:,Tspot:end-1)];                    
                        end
                        if mentalContinuum==1 && cd_wm > t %weaken mind refresh
                            wmdelete=find(keytimes(2,:)==10); %finds next weaken mind tick in queue
                            keytimes(2,wmdelete)=1; %deletes it (overwrites it with empty event)
                            T=t; %inserts a new one
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 10], keytimes(:,Tspot:end-1)];
                            wmalac = alac; %so WM ticks at the rate dictated by alacrity value upon refresh
                        end
                        tkEff = tkEff-1;
                        if damage>abilityDmg(2)*1.5 && telekinetics==1
                            tkEff=2;
                            potency = potency - 1;
                        end
                    end
                    heal=0;
                case 6 % mind crush tick
                    damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(3) * (1 + (-rand + crit > 0)*(surge + reverberation)) * (1 + FM + vulnerable);
                    if rand<mentalMomentum && mM<1 % mental momentum double tick
                        T=t;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 6], keytimes(:,Tspot:end-1)];
                        mM=2; %in case of mental momentum tick this value is going to be 1 for the procced tick, so the procced tick can't proc another tick, after that it's going to be below 1 so normal ticks cn proc them
                        cd_ma = cd_ma - tremors*1000;
                    end
                    mM=mM-1;
                    heal=0;
                case 7 % sever force application
                    if (-rand + (1-boss_defense) + acc > 0)>0 % chance to resist
                        T=t+(0:3000:18000)/(1+alac);
                        for Tt=T
                            Tspot=find(Tt<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [Tt; 8], keytimes(:,Tspot:end-1)];                    
                        end
                    end
                    force = force - sfcost;
                    cd_sf = t+18000/(1+alac);
                    damage = 0;
                    heal = 0;
                case 8 % sever force tick
                    damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(4) * (1 + (-rand + crit > 0)*surge) * (1 + drainThoughts + assailable + FM + vulnerable) * ((supp>0)*0.1 + 1) * (1 + execute);
                    force = min(600, force + 2*mindsEye * (supp>0));
                    if damage>0
                        supp = supp-1; % force suppression
                    end
                    heal = damage*balance; %heal size doesn't matter
                case 9 % weaken mind application
                    if (-rand + (1-boss_defense) + acc + telekinetics > 0)>0 % in TK this will only happen once, but will not miss, to make things easier
                        if balance==1 % in balance it's going to schedule 7 ticks
                            T=t+(0:3000:18000)/(1+alac);
                            for Tt=T
                                Tspot=find(Tt<keytimes(1,:),1);
                                keytimes = [keytimes(:,1:Tspot-1), [Tt; 10], keytimes(:,Tspot:end-1)];                    
                            end
                        else % in TK it's only going to schedule next tick
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 10], keytimes(:,Tspot:end-1)];
                            wmalac = alac; %so ticks happen  at the rate dictated by alacrity value upon activation
                        end
                    end
                    force = force - wmcost*(1-0.75*(tkEff>0));
                    tkEff = tkEff-1;
                    cd_wm = t+18000/(1+alac);
                    damage = 0;
                    heal = 0;
                case 10 % weaken mind tick
                    damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(5) * (1 + (-rand + crit > 0)*surge) * (1 + drainThoughts + assailable + FM + vulnerable) * ((supp>0)*0.1 + 1) * (1 + execute);
                    force = min(600, force + 2*mindsEye * (supp>0));
                    if damage>0
                        supp = supp-1; % force suppression
                    end
                    if telekinetics==1 % going to schedule next tick
                        T=t+3000/(1+wmalac);
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 10], keytimes(:,Tspot:end-1)];
                        cd_wm = t+18000; % this happens every tick so weaken mind in telekinetics never falls off 
                    end
%                   if damage>0 % 4-piece set bonus alacrity
%                         if setbonus(2)
%                             if cd_fma < t
%                                 if rand>0.3
%                                     cd_fma = t + 20000;
%                                     alac = alac + 0.05;
%                                     T=t+6000;
%                                     Tspot=find(T<keytimes(1,:),1);
%                                     keytimes = [keytimes(:,1:Tspot-1), [T; 26], keytimes(:,Tspot:end-1)];  
%                                 end
%                             end
%                         end
%                     end
                    heal = damage*balance; %heal size doesn't matter
                case 11 % force in balance
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(6:7)) * (1 + (-rand + crit > 0)*surge) * (FM + vulnerable + assailable + 1) * (1 + overwhelmed);
                    if (damage>0)*(forceSuppression)
                        supp=15; %gives 15 suppression stacks
                    end
                    force = force - fibcost;
                    cd_fib = t+15000/(1+alac);
                    heal = damage*balance; %heal size doesn't matter
                case 12 % disturbance
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(8:9)) * (1 + (-rand + crit + criticalKinesis > 0)*surge) * (FM + vulnerable + POM*0.2 + 1);
                    force = force - distcost*((-(POM==1)+2)/2); % disturbance cost is halved if presence of mind was used
                    if damage>0
                        pom=0;
                        POM=0;
                    end
                    heal = 0;
                case 13 % tk throw start
                    tick = 1000*(3-pP)/(1+alac)/3; % tick time
                    T=t:tick:t+3*tick;
                    for Tt=T
                        Tspot=find(Tt<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [Tt; 14], keytimes(:,Tspot:end-1)];                    
                    end
                    damage = 0;
                    heal = 0;
                case 14 % tk throw tick
                    damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(10) * (1 + (-rand + crit > 0)*surge) * (1 + FM + vulnerable -pP*0.25);
                    if damage>0
                        pom = min(pom+1,4) * presenceOfMind;
                        if isequal(pom,4)
                            POM=1;
                        end
                        force = force - tktcost/4; % seems like it might actually be rounded to 9 force per tick
                        force = min(600, force + forcePool*0.01*balance);
                        if (rand < ripplingForce*0.2)
                            ripforce = ripforce + 1;
                            T=t+1000;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 15], keytimes(:,Tspot:end-1)];                               
                        end
                    end
                    heal = 0;
                case 15 % rippling force
                    if isequal(ripforce,1) % if ripforce is more than 1 it's been overwritten / clipped
                        damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(11) * (1 + (-rand + crit > 0)*surge) * (1 + FM + vulnerable); % (1 + drainThoughts + FM + vulnerable) * ((supp>0)*0.1 + 1) * (1+execute);*((supp>0)*0.1 + 1) %if/when rippling force is fixed as dot
                        %force = force + 2*mindsEye * (supp>0); if/when rippling force is fixed as dot
                        %supp=supp-1; if/when rippling force is fixed as dot
                        ripforce = 0;
                        force = min(600, force + ripplingForce * 2);
                    else
                        ripforce = ripforce - 1;
                        damage = 0;
                    end
                    heal = 0;
                case 16 % telekinetic focal point
                    if tkfp < 5
                        alac = alac + 0.01;
                    end
                    tkfp = min(5, tkfp+1);
                    tkfpstack = tkfpstack + 1;                  
                    T=t+15000;
                    Tspot=find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; 17], keytimes(:,Tspot:end-1)];   
                    damage = 0;
                    heal = 0;
                case 17 % telekinetic focal point end
                    tkfpstack = tkfpstack - 1;
                    if (tkfpstack == 0)
                        alac = alac - tkfp/100;
                        tkfp = 0;                        
                    end
                    damage = 0;
                    heal = 0;
                case 18 % potency
                    potency = 2;
                    damage = 0;
                    heal = 0;
                    cd_fp = t+90000/(1+alac);
                case 19 % mental alacrity
                    damage = 0;
                    heal = 0;
                    if malac==0
                        cd_ma = t + (120000 - 15000*(setbonus2 + flowingForce))/(1+alac); %unaffected by itself
                        alac = alac + 0.2;
                        malac = 1; 
                        T=t+10000+5000*flowingForce;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 19], keytimes(:,Tspot:end-1)];   
                    else
                        alac = alac - 0.2;
                        malac = 0;            
                    end        
                case 20 % adrenal
                    damage = 0;
                    heal = 0;
                    if adrenalOn==0
                        cd_ad = t + 180000/(1+alac);
                        Power = Power + adrenal;
                        adrenalOn = 1;
                        T=t+15000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 20], keytimes(:,Tspot:end-1)];
                        cd_ad2 = T; % want to know when it ends in case it's possible to sqeeze in an instand tk burst                        
                    else
                        Power = Power - adrenal;
                        adrenalOn = 0;
                    end
                    bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
                    T=t;
                    Tspot=find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];   
%                 case 21 % power relic
%                     damage = 0;
%                     if relic1>0
%                         if powerrelicOn==0
%                             cd_re = t + 120000/(1+alac);
%                             Power = Power + powerrelic;
%                             powerrelicOn=1;
%                             T=t+30000;
%                             Tspot=find(T<keytimes(1,:),1);
%                             keytimes = [keytimes(:,1:Tspot-1), [T; 21], keytimes(:,Tspot:end-1)];   
%                         else
%                             Power = Power - powerrelic;
%                             powerrelicOn=0;
%                         end
%                     bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
%                     T=t;
%                     Tspot=find(T<keytimes(1,:),1);
%                     keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];
%                     heal = 0;
%                     end
                case 22 % potency + fib
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(6:7)) * (1 + (-rand + crit + 0.6 > 0)*surge) * (FM + vulnerable + assailable + 1) * (1 + overwhelmed);
                    if (damage>0)*(balance)
                        supp=15;
                        if (damage > 1.5*abilityDmg(7)) % if it crits
                            potency = potency - 1;
                        end
                    end
                    force = force - fibcost;
                    cd_fib = t+15000/(1+alac);
                    heal = damage; %heal size doesn't matter
%                 case 23 % potency + tkt
%                     tick = 1000*(3-pP)/(1+alac)/3; % tick time
%                     T=t:tick:t+3*tick;
%                     for Tt=T
%                         Tspot=find(Tt<keytimes(1,:),1);
%                         keytimes = [keytimes(:,1:Tspot-1), [Tt; 24], keytimes(:,Tspot:end-1)];                    
%                     end
%                     damage = 0;
%                     potency = potency - 1;
%                     heal = 0;
%                 case 24 % potency + tkt ticks
%                     damage = (-rand + (1-boss_defense) + acc > 0) * abilityDmg(10) * (1 + (-rand + crit + 0.6 > 0)*surge) * (1 + FM + vulnerable -pP*0.25);
%                     if damage>0
%                         pom = min(pom+1,4) * presenceOfMind;
%                         if isequal(pom,4)
%                             POM=1;
%                         end
%                         force = force - tktcost/4;
%                         force = min(600, force + forcePool*0.01*balance);
%                         if (rand < ripplingForce*0.2)
%                             ripforce = ripforce + 1;
%                             T=t+1000;
%                             Tspot=find(T<keytimes(1,:),1);
%                             keytimes = [keytimes(:,1:Tspot-1), [T; 15], keytimes(:,Tspot:end-1)];
%                         end
%                     end
%                     heal = 0;
                case 25 % power proc relic off
                    Power = Power - procrelic;
                    damage = 0;
                    bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
                    T=t;
                    Tspot=find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];
                    heal = 0;
%                 case 26 % 4-piece set bonus alacrity off
%                     alac = alac - 0.05;
%                     damage = 0;
%                     heal = 0;
                case 27 % turbulence
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(14:15)) * (1 + (-rand + crit + ((cd_wm-t)>0) + 0.6*(potency>0) > 0)*(surge + reverberation)) * (FM + vulnerable + assailable + 1);
                    cd_tu = t+9000/(1+alac);
                    force = force - tucost*(1-0.75*(tkEff>0));
                    tkEff = tkEff-1;
                    if t>cd_tf %tidal force - applies even if it's a resist
                            TF=1;
                            cd_tf=t+10000/(1+alac); %check if icd affected by alacrity - yep
                            T=t+10000;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 34], keytimes(:,Tspot:end-1)];
                            cd_tw=t-1;
                    end
                    if cd_fm<t && setbonus1==1 %force master 2% damage proc - also applies if it's a resist
                        FM = 0.02;
                        T=t+15000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 31], keytimes(:,Tspot:end-1)];
                        cd_fm = t + 30000/(1+alac);
                    end
                    if damage>abilityDmg(15)*1.5 %if crit
                        tkEff=2;
                        potency = potency - 1;
                    end
                    if rand<mentalMomentum %30% chance for proc - also works if attack is resisted
                        T=t+50; % scheduled 50ms after main hit
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 35], keytimes(:,Tspot:end-1)];
                        cd_ma = cd_ma - tremors*1000;
                    end
                    heal=0;
                case 28 % tk gust
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(22:23)) * (1 + (-rand + crit + 0.6*(potency>0) > 0)*(surge + reverberation)) * (FM + vulnerable + 1);
                    cd_tg = t + 12000/(1+alac);
                    cd_tg2 = t + 12000; %for proc
                    force = force - tgcost*(1-0.75*(tkEff>0));
                    tkEff = tkEff - 1;
                    if damage>0
                        if damage>abilityDmg(23)*1.5
                            tkEff=2;
                            potency = potency - 1;
                        end
                        if (rand < telekineticFocalPoint)
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 16], keytimes(:,Tspot:end-1)];   
                        end
                    end
                    if rand<(telekineticMomentum*(1+malac*flowingForce)) %30% chance for proc
                        T=t+50; % scheduled 50ms after main hit
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 37], keytimes(:,Tspot:end-1)];
                        cd_ma = cd_ma - tremors*1000;
                    end
                    heal = 0;
                case 29 % tk wave
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(12:13)) * (1 + (-rand + crit + 0.6*(potency>0) > 0)*(surge + reverberation)) * (FM + vulnerable + 1) * (1 + overwhelmed);
                    cd_tw = t+6000/(1+alac);
                    force = force - twcost*(1-TF/2)*(1-0.75*(tkEff>0));
                    tkEff = tkEff - 1;
                    if damage>0
                        TF=0;
                        if damage>abilityDmg(13)*1.5 %telekinetic effussion
                            tkEff=2;
                            potency = potency - 1;
                        end
                        if (rand < telekineticFocalPoint) %telekinetic focal point
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 16], keytimes(:,Tspot:end-1)];   
                        end
                        if mentalContinuum==1 %weaken mind refresh
                            wmdelete=find(keytimes(2,:)==10); %finds next weaken mind tick in queue
                            keytimes(2,wmdelete)=1; %deletes it
                            T=t; %inserts a new one
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 10], keytimes(:,Tspot:end-1)];
                            wmalac = alac; %so ticks tick at the rate dictated by alacrity value upon activation
                        end
                    end
                    if rand<(telekineticMomentum*(1+malac*flowingForce)) %30% chance for proc
                        T=t+50; % scheduled 50ms after main hit
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 36], keytimes(:,Tspot:end-1)];
                        cd_ma = cd_ma - tremors*1000;
                    end
                    heal = 0;
                case 30 % tk burst
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(24:25)) * (1 + (-rand + crit + 0.6*(potency>0) > 0)*surge) * (FM + vulnerable + 1);
                    force = force - tbcost*(1-0.75*(tkEff>0));
                    tkEff=tkEff-1;
                    cf = cf - 1; % clamoring force
                    cd_fp = cd_fp - 1000*setbonus3; % actually works on activation rather than on successful cast, but doesn't make a difference
                    if t>cd_tf %tidal force
                        TF=1;
                        cd_tf=t+10000/(1+alac);
                        T=t+10000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 34], keytimes(:,Tspot:end-1)];
                        cd_tw=t-1;
                    end
                    if damage>abilityDmg(25)*1.5
                        tkEff=2;
                        potency = potency - 1;
                    end
                    if mentalContinuum==1
                        T=t; %schedules mental continuum 10% force regen case
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 39], keytimes(:,Tspot:end-1)];
                    end
                    if rand<(telekineticMomentum*(1+malac*flowingForce)) %30% chance for proc
                        T=t+50; % scheduled 50ms after main hit
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 38], keytimes(:,Tspot:end-1)];
                        cd_ma = cd_ma - tremors*1000;
                    end
                    heal=0;
                case 31 % force master 2% damage runs out
                    damage = 0;
                    FM = 0;
                    heal = 0;
                case 32 % force empowerment
                    if isequal(ForceEmpowerment,0)
                        mainStat = mainStat * 1.15/1.05; % stacks additively with consular buff
                        ForceEmpowerment = 1;
                        T=t+10000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 32], keytimes(:,Tspot:end-1)]; 
                        cd_fe = t + 300000;
                    else
                        mainStat = mainStat * 1.05/1.15;
                        ForceEmpowerment = 0;
                    end
                    crit = 0.3*(1-(1-(1/30)).^(critical/60/0.9)) + 0.2*(1-(1-(1/20)).^(mainStat/60/5.5)) + critBuff + 0.05; % 5 % base crit
                    bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
                    T=t;
                    Tspot=find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];
                    damage = 0;
                    heal = ForceEmpowerment; % Force Empowerment heals
                case 33 % mainstat proc relic goes off
                    mainStat = mainStat - procrelic * (1.05 + 0.1*ForceEmpowerment);
                    damage = 0;
                    crit = 0.3*(1-(1-(1/30)).^(critical/60/0.9)) + 0.2*(1-(1-(1/20)).^(mainStat/60/5.5)) + critBuff + 0.05; % 5 % base crit                    
                    bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
                    T=t;
                    Tspot=find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];                    
                    heal = 0;
                case 34 % tidal force proc runs out, hasn't occured in a few thousands of runs but oh well
                    if t==cd_tf %in case tidal force has not been refreshed in the meantime
                        TF = 0;
                    end
                    damage = 0;
                    heal=0;
                case 35 % turbulence mental momentum - currently not set at 30% in game, but that should get fixed
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(14:15))*0.3 * (1 + (-rand + crit + ((cd_wm-t)>0)> 0)*(surge + reverberation)) * (FM + vulnerable + assailable + 1);
                    if t>cd_tf %tidal force proc
                        TF=1;
                        cd_tf=t+10000/(1+alac);
                        T=t+10000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 34], keytimes(:,Tspot:end-1)];
                        cd_tw=t-1;
                    end
                    if cd_fm<t && setbonus1==1 %force master 2% damage proc
                        FM = 0.02;
                        T=t+15000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 31], keytimes(:,Tspot:end-1)];
                        cd_fm = t + 30000/(1+alac);
                    end
                    if damage>abilityDmg(15)*0.45 %if crit
                        tkEff=2;
                    end
                    heal = 0;
                case 36 %tk wave telekinetic momentum
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(12:13))*0.3 * (1 + (-rand + crit > 0)*(surge + reverberation)) * (FM + vulnerable + 1) * (1 + overwhelmed);
                    if damage>0
                        TF=0;
                        if damage>abilityDmg(13)*0.45 %telekinetic effussion
                            tkEff=2;
                        end
                        if (rand < telekineticFocalPoint) %telekinetic focal point
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 16], keytimes(:,Tspot:end-1)];   
                        end
                        if mentalContinuum==1 %weaken mind refresh
                            wmdelete=find(keytimes(2,:)==10); %finds next weaken mind tick in queue
                            keytimes(2,wmdelete)=1; %deletes it
                            T=t; %inserts a new one
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 10], keytimes(:,Tspot:end-1)];
                            wmalac = alac; %so ticks tick at the rate dicated by alacrity value upon activation
                        end
                    end
                    heal = 0;
                case 37 %tk gust telekinetic momentum
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(22:23))*0.3 * (1 + (-rand + crit > 0)*(surge + reverberation)) * (FM + vulnerable + 1);
                    if damage>0
                        if damage>abilityDmg(23)*0.45
                            tkEff=2;
                        end
                        if (rand < telekineticFocalPoint)
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 16], keytimes(:,Tspot:end-1)];   
                        end
                    end
                    heal = 0;
                case 38 %tk burst telekinetic momentum
                    damage = (-rand + (1-boss_defense) + acc > 0) * randi(abilityDmg(24:25))*0.3 * (1 + (-rand + crit > 0)*surge) * (FM + vulnerable + 1);
                    if t>cd_tf
                        TF=1;
                        cd_tf=t+10000/(1+alac); %check if icd affected by alacrity
                        T=t+10000;
                        Tspot=find(T<keytimes(1,:),1);
                        keytimes = [keytimes(:,1:Tspot-1), [T; 34], keytimes(:,Tspot:end-1)];
                        cd_tw=t-1;
                    end
                    if damage>abilityDmg(25)*0.45
                        tkEff=2;
                    end
                    heal = 0;
                case 39 % mental continuum force regen stacks - same procedure as telekinetic focal point stacks (16,17)
                    if mcont < 3
                        mcont = mcont + 1;
                    end
                    mcont = min(3, mcont+1);
                    mcontstack = mcontstack + 1;                  
                    T=t+10000;
                    Tspot=find(T<keytimes(1,:),1);
                    keytimes = [keytimes(:,1:Tspot-1), [T; 40], keytimes(:,Tspot:end-1)];   
                    damage = 0;
                    heal=0;
                case 40 % mental continuum force regen stacks fall off
                    mcontstack = mcontstack - 1;
                    if (mcontstack == 0)
                        mcont = 0;                        
                    end
                    damage = 0;
                    heal = 0;
                case 41 % force speed
                    cd_fs = t+15000; % might as well go for talented version if using it at all
                    cf = 2; % two stacks of clamoring force
                    damage = 0;
                    heal = 0;
                otherwise
                    disp(['case for mode ', num2str(action), ' does not exist'])
                    damage = 0;
                    heal = 0;
            end

            damage = round(damage);
            if damage > 0 || heal > 0
                chance = 1 - (1-0.3)^((heal>0)+(damage>0)); % 30% chance if either heal or damage, 51% if both
                if relic2 > 0
                    if cd_mp < t % mainstat proc relic, no double proc bug
                        if rand < chance
                            mainStat = mainStat + procrelic * (1.05 + 0.1*ForceEmpowerment);
                            crit = 0.3*(1-(1-(1/30)).^(critical/60/0.9)) + 0.2*(1-(1-(1/20)).^(mainStat/60/5.5)) + critBuff + 0.05; % 5 % base crit
                            bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];
                            cd_mp = t+20000/(1+alac);
                            T=t+6000;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 33], keytimes(:,Tspot:end-1)];
                            log(:,i) = [t; 100; 0; force];
                            i=i+1;
                        end
                    end
                end
                if relic3 > 0
                    if cd_pp < t % power proc relic, no double proc bug
                        if rand < chance
                            Power = Power + procrelic;
                            cd_pp = t+20000/(1+alac);
                            T=t+6000;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 25], keytimes(:,Tspot:end-1)];
                            bonusDmg = (Power*0.23 + mainStat*0.2) * (1 + bonusDmgBuff);
                            T=t;
                            Tspot=find(T<keytimes(1,:),1);
                            keytimes = [keytimes(:,1:Tspot-1), [T; 0], keytimes(:,Tspot:end-1)];
                            log(:,i) = [t; 101; 0; force];
                            i=i+1;
                        end
                    end
                end
%                 if relic4
%                     if cd_pd<t % damage proc relic
%                         if rand < chance
%                             damage = (-rand + (1-boss_defense) + acc > 0) * (1 + (-rand + crit > 0)*surge) * 264;
%                             damage = damage + 264;
%                             cd_pd = t+4500;
%                         end
%                     end
%                 end
            end
%            log(:,i) = [t; action; damage; force]; %basic combat log for debugging purposes. If enabled, sim runs slightly slower. It has to be single single thread so change "parfor" to "for"
            i = i+1;
            totaldmg = totaldmg + damage;
            if totaldmg > bossHP30
                execute = 0.15 * mentalScarring;
                if totaldmg > bossHP
                    break
                end
            end
        end
        % dps calculator
        dps(j,:)=[min(totaldmg, bossHP)*1000/t, t/1000];
    end

    mindps = min(dps(:,1));
    meandps = mean(dps(:,1));
    maxdps = max(dps(:,1));
    dpsinc(istat,:) = [mainStatBase, powerBase, criticalBase, accuracyBase alacrityBase, surgBase, mindps meandps maxdps];
    
    istat=istat+1;
    disp([mainStatBase, powerBase, criticalBase, accuracyBase alacrityBase, surgBase, mindps meandps maxdps]);

end

toc
