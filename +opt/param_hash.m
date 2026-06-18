function id = param_hash(x)
%PARAM_HASH Stable readable id for an optimization vector.
txt = sprintf('%+.6f_', x(:));
try
    md = java.security.MessageDigest.getInstance('MD5');
    bytes = typecast(md.digest(uint8(txt)), 'uint8');
    id = lower(sprintf('%02x', bytes(1:6)));
    id = ['x' id];
catch
    id = ['x' regexprep(sprintf('%+.3f_', x(:)), '[^0-9A-Za-z]+', '_')];
    id = id(1:min(numel(id), 40));
end
end
