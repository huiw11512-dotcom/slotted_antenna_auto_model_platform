function conductance = power_to_conductance(weights, array)
% Convert desired aperture power into normalized slot conductances.
%
% For the resonant standing-wave baseline used here, the textbook matching
% rule is that the normalized conductances assigned along one resonant array
% sum to unity. In the symmetric center-fed topology, that means:
% - all branch-coupling slots across the main manifold sum to 1
% - all radiating slots within one branch sum to 1
%
% Wpow is Ny x Nx where:
%   Ny = number of radiating-slot positions along each branch (y direction)
%   Nx = number of branch guides across the panel (x direction)

P = weights.Wpow;   % Ny x Nx, normalized total power
Ny = array.Ny;
Nx = array.Nx;

rowPos = ((1:Ny) - (Ny+1)/2) * array.dy_mm; % y positions along branch guides
colPos = ((1:Nx) - (Nx+1)/2) * array.dx_mm; % x positions of branch guides

% Branch power across x for main-guide coupling.
branchPower = sum(P, 1).';

halfX = Nx/2;
feedPairs = zeros(halfX, 1);
feedXmm = zeros(halfX, 1);
feedG = zeros(halfX, 1);
for k = 1:halfX
    j1 = halfX + 1 - k;
    j2 = halfX + k;
    feedPairs(k) = branchPower(j1) + branchPower(j2);
    feedXmm(k) = abs(colPos(j2));
    % Individual coupling-slot conductance on each side of the center feed.
    feedG(k) = 0.5 * (branchPower(j1) + branchPower(j2));
end

% Radiating conductance per branch, solved on symmetric y pairs.
halfY = Ny/2;
radG = zeros(Nx, halfY);
radPairPower = zeros(Nx, halfY);
radYmm = zeros(1, halfY);
for n = 1:halfY
    i1 = halfY + 1 - n;
    i2 = halfY + n;
    radYmm(n) = abs(rowPos(i2));
    for ix = 1:Nx
        radPairPower(ix,n) = P(i1,ix) + P(i2,ix);
    end
end
for ix = 1:Nx
    if branchPower(ix) <= eps
        continue;
    end
    pBranch = P(:,ix) / branchPower(ix);
    for n = 1:halfY
        i1 = halfY + 1 - n;
        i2 = halfY + n;
        % Individual radiating-slot conductance on either side of the branch center.
        radG(ix,n) = 0.5 * (pBranch(i1) + pBranch(i2));
    end
end

conductance = struct();
conductance.branchPower = branchPower;
conductance.branchPos_mm = colPos;
conductance.slotPos_mm = rowPos;
conductance.feed_pair_power = feedPairs;
conductance.feed_pair_x_mm = feedXmm;
conductance.feed_pair_g = feedG;
conductance.rad_pair_power = radPairPower;
conductance.rad_pair_y_mm = radYmm;
conductance.rad_pair_g = radG;
end
