function subtract_keep_tool(fid, blankParts, toolParts)
% Subtract tool parts from blank parts while keeping the tool objects.

blankStr = local_join_names(blankParts);
toolStr  = local_join_names(toolParts);

fprintf(fid, '\n');
fprintf(fid, 'oEditor.Subtract _\n');
fprintf(fid, 'Array("NAME:Selections", _\n');
fprintf(fid, '"Blank Parts:=", _\n');
fprintf(fid, '"%s", _\n', blankStr);
fprintf(fid, '"Tool Parts:=", _\n');
fprintf(fid, '"%s"), _\n', toolStr);
fprintf(fid, 'Array("NAME:SubtractParameters", _\n');
fprintf(fid, '"KeepOriginals:=", true)\n');

end

function s = local_join_names(parts)
if isstring(parts)
    parts = cellstr(parts);
end
if ischar(parts)
    s = parts;
elseif iscell(parts)
    parts = parts(~cellfun(@isempty, parts));
    parts = cellfun(@char, parts, 'UniformOutput', false);
    s = strjoin(parts, ',');
else
    error('Unsupported parts type.');
end
end
