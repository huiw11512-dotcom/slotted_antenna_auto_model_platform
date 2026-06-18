function score = score_results(metrics, cfg, x, vars)
%SCORE_RESULTS Compute optimization objective from exported EM data.
if nargin < 2 || isempty(cfg)
    cfg = opt.default_config();
end
if nargin < 3
    x = [];
end
if nargin < 4
    vars = struct([]);
end

score = struct();
score.objective = NaN;
score.status = 'needs_solver_results';
score.s11_penalty = NaN;
score.sll_penalty = NaN;
score.beam_penalty = NaN;
score.gain_penalty = NaN;
score.regularization = local_regularization(x, vars);
score.details = struct();

if isempty(metrics) || ~isfield(metrics, 'available') || ~metrics.available
    return;
end

[s11Penalty, s11Info] = local_s11_penalty(metrics, cfg);
[sllPenalty, beamPenalty, gainPenalty, cutInfo] = local_pattern_penalty(metrics, cfg);

score.s11_penalty = s11Penalty;
score.sll_penalty = sllPenalty;
score.beam_penalty = beamPenalty;
score.gain_penalty = gainPenalty;
score.details.s11 = s11Info;
score.details.cuts = cutInfo;
score.status = 'scored';
score.objective = cfg.weights.s11*s11Penalty + ...
    cfg.weights.sll*sllPenalty + ...
    cfg.weights.beam*beamPenalty + ...
    cfg.weights.gain*gainPenalty + ...
    cfg.weights.regularization*score.regularization;
end

function [penalty, info] = local_s11_penalty(metrics, cfg)
info = struct();
if isempty(metrics.s11)
    penalty = NaN;
    info.note = 'missing_s11';
    return;
end
s11 = metrics.s11.s11_dB(:);
excess = max(s11 - cfg.targets.s11_dB, 0);
penalty = mean(excess.^2, 'omitnan');
info.min_s11_dB = min(s11);
info.max_inband_s11_dB = max(s11);
end

function [sllPenalty, beamPenalty, gainPenalty, info] = local_pattern_penalty(metrics, cfg)
cuts = {};
if ~isempty(metrics.phi0)
    cuts{numel(cuts)+1} = metrics.phi0;
end
if ~isempty(metrics.phi90)
    cuts{numel(cuts)+1} = metrics.phi90;
end

sllPenalty = 0;
beamPenalty = 0;
gainPenalty = 0;
if isempty(cuts)
    sllPenalty = NaN;
    beamPenalty = NaN;
    gainPenalty = NaN;
    info = struct('cut', []);
    return;
end

cutInfo = repmat(struct('peak_dB', [], 'peak_theta_deg', [], 'sll_dB', []), 1, numel(cuts));
for k = 1:numel(cuts)
    theta = cuts{k}.theta_deg(:);
    gain = cuts{k}.value_dB(:);
    [peakGain, peakIdx] = max(gain);
    peakTheta = theta(peakIdx);
    sll = local_sll(theta, gain, cfg.main_lobe_exclusion_deg);
    sllPenalty = sllPenalty + max(sll - cfg.targets.sll_dB, 0)^2;
    beamPenalty = beamPenalty + max(abs(peakTheta - cfg.targets.beam_theta_deg) - ...
        cfg.targets.beam_tolerance_deg, 0)^2;
    if ~isempty(cfg.targets.min_peak_dBi)
        gainPenalty = gainPenalty + max(cfg.targets.min_peak_dBi - peakGain, 0)^2;
    end
    cutInfo(k).peak_dB = peakGain;
    cutInfo(k).peak_theta_deg = peakTheta;
    cutInfo(k).sll_dB = sll;
end
info = struct('cut', cutInfo);
end

function sll = local_sll(theta, gain, exclusionDeg)
[peakGain, peakIdx] = max(gain);
peakTheta = theta(peakIdx);
sideMask = abs(theta - peakTheta) >= exclusionDeg;
if ~any(sideMask)
    sll = NaN;
    return;
end
sll = max(gain(sideMask)) - peakGain;
end

function penalty = local_regularization(x, vars)
if isempty(x) || isempty(vars)
    penalty = 0;
    return;
end
x0 = [vars.x0].';
span = max([vars.ub].' - [vars.lb].', eps);
penalty = mean(((x(:) - x0) ./ span).^2);
end
