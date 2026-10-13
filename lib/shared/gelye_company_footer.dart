import 'package:flutter/material.dart';

/// Shared application branding. Integrate at the common application shell
/// instead of duplicating this widget in 35 section screens.
class GelyeCompanyFooter extends StatelessWidget {
  const GelyeCompanyFooter({super.key,required this.version});
  final String version;
  @override
  Widget build(BuildContext context) => SafeArea(
    top:false,
    child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('All Rights Reserved for Gelye Sherane Café & Rest',
          textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
        Text('Powered By Zanyar Sidqi',
          textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
        Text('Version $version',textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.labelSmall),
      ]),
    ),
  );
}

/// Shared receipt footer for all future bill/PDF/POS renderers.
const gelyeBillPoweredBy = 'Powered By Zanyar Sidqi';
