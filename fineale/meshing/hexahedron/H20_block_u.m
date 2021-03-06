function [fens,fes] = H20_block_u(Length,Width,Height,nL,nW,nH)
% Mesh of a 3-D block of H20 finite elements (unstructured)
%
% function [fens,fes] = H20_block_u(Length,Width,Height,nL,nW,nH)
%
% Arguments:
% Length,Width,Height= dimensions of the mesh in Cartesian coordinate axes,
% smallest coordinate in all three directions is  0 (origin)
% nL,nW,nH=number of elements in the three directions
%
% Range in xyz =<0,Length> x <0,Width> x <0,Height>
% Divided into elements: nL, nW, nH in the first, second, and
% third direction (x,y,z). Finite elements of type H20.
%
% Output:
% fens= finite element node set
% fes = finite element set
%
%
% Examples: 
%     [fens,fes] = H20_block_u(2,3,4, 1,2,3);
%     drawmesh({fens,fes},'nodes','fes','facecolor','none'); hold on
%
% See also: H8_block_u, H8_to_H20
%
    [fens,fes] = H8_block_u(Length,Width,Height,round(nL/2),round(nW/2),round(nH/2));
    [fens,fes] = H8_to_H20(fens,fes);
end
