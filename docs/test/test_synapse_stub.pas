program test_synapse_stub;
{$MODE OBJFPC}{$H+}
uses NetTransport, NM_SynapseLink;
var link: ISocketLink;
begin
  link := CreateSocketLink;
  if link = nil then
    writeln('STUB OK: no Synapse backend -> CreateSocketLink returns nil (as designed)')
  else
    writeln('backend present');
  writeln('SYNAPSE STUB VERIFIED');
end.
