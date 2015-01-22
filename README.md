This is an event driven simulation written in Matlab that models player dps in SWTOR.
In other words, it does dummy parses with different gear stats so I don't have to.

% COMMENTS

%raid debuffs
%%If dummy module is off, 5% Vulnerable debuff is applied by Mind Crush or Vanquish and does not ever fall off. Vulnerable is applied before their damage takes place, so the damage is affected by it. Always keep it on for this reason.
%Similar for Overwhelmed - if dummy module is off then, apart from first hit that applies it, this debuff is always present. Max error from this will be less than 0.1% 

%discipline stuff - talents below are implemented directly, the others can be turned on and off for debugging

%Psychic Barrier - tkt returns 1% of the force - this would push down minimum force 
%needed to activate tkt to 10, but for safety measure it's kept at 24. 
%If you were extremely unlucky with accuracy you might not be able to get force back at a decent rate which might push 
%force into negative numbers. Regardless, this should be an extremely border case scenario. Clipping tkt is not implemented.
% tidalForce=telekinetics; %Disturbance, TK Burst and Turbulence finish cd on TK Wave, make it instant and cost 50% force - OK
% resonatingVibrations=telekinetics; %Increases crit chance of Forcequake by 15% and critical multiplier by 30% - Leaving this one out for now, assuming FQ will get nerfed and won't have a place in single target rotation
% telekineticEffusion=telekinetics; %direct force attack crits grant TK Effusion, which reduces force consumed by next 2 non-channeled force attacks by 75% - looks OK
% concentration=telekinetics; %makes disturbance instant when taking damage - sages don't take damage, sages DO damage
% clamoringForce=telekinetics; % 2 instant TK Bursts or Distrubances after Force Speed - useful for squeezing in extra TK Burst into mental alacrity or adrenal window, but leaving out for the time being
% telekineticGust=telekinetics; %reduces activation time of MC by 0.5 seconds, effect lasts for 12 seconds

% Quick explanation on how this works

% The code simulates a dummy fight by doing a priority-based rotation. The rotation is fairly simple, solid, but an excellent player could do better.
% It turns out though, that small changes to rotation do not significantly impact optimal gearing choices which is what this simulation is about.
%
% Simulation does what a player would do on a dummy fight. It chooses attacks and cooldowns based on which are available at the moment and uses them until a certain amount of damage is
% done. Abilities it uses go on cooldown, use energy, proc effects. Every damaging ability can crit or miss. Relics can proc from damage and/or healing. Simulation will usually
% do a predetermined amount of "parses" and average them to get a more general result. 1000 are enough to get a general idea, but more than 10000 are needed
% to reduce effects of RNG to 0.1%.
%
% The core of the simulation, the "parsing", has two important parts. First one is a matrix of "key times" which is where a buffer of planned attacks or events is saved. Every iteration, 
% the simulation checks the keytimes matrix for the next ability/event to take place, deletes it from the matrix and shifts the consecutive events one place left.
% The ability/event is then executed with the help of a large switch function.
%
% Here's an chunk of a keytimes matrix, it's the opener in telekinetics
% keytimes(:,1:9)=[10  20  40  1000  1540  1540  1540  2840  2860;
%                  0   5   9   -2    19    20    32    27    -1   ];
% The top row represents time in miliseconds. It's always going to be ordered lowest->highest. Bottom row represents abilities or events. The simulation takes the first column, sets current time to 10 and 
% executes event "0" (calculating ability damage based on stats). It then deletes this column, and puts second ([20; 5]) column on first place, third column on 2nd and so on.
% A [1000000, 1000000] value is appended at the end to keep the same size. Next, it sets time to 20ms, executes event "5" (Mind Crush hit), deletes column, shifts other olumns left etc.
% Events themselves can insert new events into this matrix. For example, Mind Crush activation will schedule 6 Mind Crush ticks. There's also a rotation event which schedules a new
% ability and next rotation event, so the matrix is always partly full.
%
% "-1" event represents rotation. In this part all possible abilities get a weight assigned to them. The ability with highest weight will be scheduled as the next event in keytimes matrix
% Depending on spec, the abilities that aren't used in it will all keep "0" value. An example in telekinetics for Mind Crush and Turbulence:
% tb = (cd_tu<=t) * 20 * (force >= tucost*(1-0.75*(tkEff>0)));
% mc = (cd_mc<=t) * 18 * (force >= mccost*(1-0.75*(tkEff>0))) * (cd_tg2>t);
% tb and mc are weights
% cd_tu and cd_mc are respective cooldowns of those abilities. For example, when Turbulence is activated, its cooldown is set to time of activation + 9 seconds (no alacrity in example). 
% (cd_tu<=t) checks if it the ability is ready yet. If not, its weight will be 0.
% (force >= tucost*(1-0.75*(tkEff>0))) is a similar check but for force. It will get a value of 0 if force is below needed. Force requirement is lower if Telekinetic Effussion is present
% (cd_tg2>t) is a special case, it means telekinetic gust effect has run out and mind crush would have 2 seconds activation time, so it would set its weight to 0 in that case
