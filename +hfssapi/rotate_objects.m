function rotate_objects(fid, objectList, axis, angleValue)
nObjects = length(objectList);

fprintf(fid, '\n');
fprintf(fid, 'oEditor.Rotate _\n');
fprintf(fid, 'Array("NAME:Selections", _\n');
fprintf(fid, '"Selections:=", "');
for iObj = 1:nObjects
    fprintf(fid, '%s', objectList{iObj});
    if iObj ~= nObjects
        fprintf(fid, ',');
    end
end
fprintf(fid, '"), _\n');

fprintf(fid, 'Array("NAME:RotateParameters", _\n');
fprintf(fid, '"RotateAxis:=", "%s", _\n', axis);
if isnumeric(angleValue)
    fprintf(fid, '"RotateAngle:=", "%0.15gdeg") \n', angleValue);
else
    fprintf(fid, '"RotateAngle:=", "%s") \n', angleValue);
end
end
