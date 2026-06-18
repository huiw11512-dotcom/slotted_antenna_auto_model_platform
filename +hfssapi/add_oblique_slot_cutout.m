function add_oblique_slot_cutout(fid, name, center_mm, length_mm, width_mm, thk_mm, angle_deg)
% Create a thin slot-cut box, rotate around its own center in the XY plane.
centerExpr = local_to_expr_vector(center_mm, 'mm');
lengthExpr = local_to_expr(length_mm, 'mm');
widthExpr = local_to_expr(width_mm, 'mm');
thkExpr = local_to_expr(thk_mm, 'mm');

start_mm = {
    local_sub(centerExpr{1}, local_div(lengthExpr, '2'))
    local_sub(centerExpr{2}, local_div(widthExpr, '2'))
    local_sub(centerExpr{3}, local_div(thkExpr, '2'))
    };
size_mm = {lengthExpr, widthExpr, thkExpr};

hfssapi.add_slot_cutout(fid, name, start_mm, size_mm);
hfssMove(fid, {name}, {local_neg(centerExpr{1}), local_neg(centerExpr{2}), local_neg(centerExpr{3})}, 'mm');
hfssapi.rotate_objects(fid, {name}, 'Z', angle_deg);
hfssMove(fid, {name}, centerExpr, 'mm');
end

function out = local_to_expr_vector(v, units)
if iscell(v)
    out = reshape(v, numel(v), 1);
    return;
end
v = reshape(v, numel(v), 1);
out = cell(size(v));
for k = 1:numel(v)
    out{k} = local_to_expr(v(k), units);
end
end

function out = local_to_expr(v, units)
if isnumeric(v)
    if isempty(units)
        out = sprintf('%0.15g', v);
    else
        out = sprintf('%0.15g%s', v, units);
    end
else
    out = char(string(v));
end
end

function out = local_div(a, b)
out = sprintf('((%s)/(%s))', a, b);
end

function out = local_sub(a, b)
out = sprintf('((%s)-(%s))', a, b);
end

function out = local_neg(a)
out = sprintf('(-(%s))', a);
end
