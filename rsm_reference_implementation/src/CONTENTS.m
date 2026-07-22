% MATLAB RSM reference implementation, Revision 1.0.
%
% Core classes
%   Sens       - Elementary sensor adapter.
%   RsmCfg     - Generator configuration.
%   RsmDom     - Shared image/ground domain and normalization.
%   RsmPoly    - Executable rational polynomial model.
%   RsmGrid    - Executable 3-D trilinear grid model.
%   RsmAdj     - Executable adjustable-parameter model.
%   RsmDir     - Executable direct image covariance model.
%   RsmGen     - End-to-end generator.
%   RsmProd    - Product and TRE container.
%   ToyPb      - Concrete constant-velocity pushbroom example.
%   TreWriter  - Profile-driven fixed-width writer.
%
% TRE semantic classes
%   RsmIda, RsmPia, RsmPca, RsmGia, RsmGga
%   RsmApa, RsmApb, RsmEca, RsmEcb, RsmDca, RsmDcb
%
% Numerical functions
%   mkdom, mksamp, rpc00bexp, rsmexp, rpc2rsm, rsm2rpc
%   pterm, fitrat, fitlin, evalrat, mkgrid, fdjac, condcov
%   redbasis, fitadj, mkdirect, propcov, mccov, packtri
%
% Entry points
%   run_demo, make_product, collect_fields, schema_example
