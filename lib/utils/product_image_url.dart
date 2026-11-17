import '../models/app_models.dart';
import 'drive_image_url.dart';

const _apachePizza =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDCD6XVNHwfwuWPYFsvTe9a_MhxyveiwbIdNY25h5-kPyZxETueH7dPe7K2kkS3tTnzpCCda1aMozaIl4nPf2PqIvLIy6CUJKfLo7UsJG40tL2Sfl3nI2kEMN_L76OdRxaBEO1WKR2ZeGWpIQq1TxyclqEGf9PLGKkv66yZacA-SSatVENLQPwm_p483fGMhW-lkiwCtbUTUxBLLRZrW1PVJsX5-vuOdyQ4gImsnIpNAD5aTBnUHI6i';
const _meatPizza =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAzehi8245QpvBdgt8SzekevawaeuzZSFR1c3WbSDHOBsuQKEQiHSoE0cNwj_h1zVsguHaNKGuiLU94yyFQjTS3C-sw6PQ8vDXbgqrPtDpKbefHJYev2lj3Y32QPGLYxH_VCZxtDXmTz5xvUuFBWefSkj0ETTQjKhaa4WwgBnWcFqBrTjqxitwoCX-MEbMd0UT9tAknmcas3xt1UYCoZoRGip9FjDzZZubFODWXWQwXZ6O_4UInMpTy';
const _fourCheesePizza =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuD_z76oZ7HrIS35WT15cyBC96WZfEv0nk4w6ZMlLrh3OC1aCquzb3URoKqMvhNKTNDsd442wv0B8ARVbP2-nFhEfI2PfEsTJEnKkoWNMd4wandqeDa2YYBHBQ3lqubPNtoMV-DxWc6QPjDneicdxWCKASOi9G4z390O8co97LH5MsMrgfRgHwyBTPJa_2Cp2Kf-GZM2QhPP31bj5Pk8Z6vwz89zgAI-FLF9KcKxklWv-xcDKt_Y0Uag';
const _andeanPizza =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBWBYVCOONeOEFiWd3M-aWaHu1JOOajVPjL9SY_s3YSxQ9e0ilJyZLOL4eJfwVjtL4lejh-7But2OI5g8tC18GkAWU102yuCE_NHKQgTGnqwVlt31PJzrOE5OnnGJLl4DBQqufbEPXcelJIX5020tUXd6YQZpqfNLEsEY4rKrBRsehtI-NbruUFFYfl5AhiAT67MPeYVS7rCW3ct8-r3Vcl3b78MfSrQUwRrnsJndLPyltxkdS7iXsQ';
const _inkaCola =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBWUyYRUzY6J2vhfflSf3n5gH_A5QY1hUPFvBCLufIpcwqs5DEDEUOSXCx6gBGVpd4WVOsNWPv309KFXoDCAh-B1kpaTIl9AtvqlZDUPnlgdnUDQV6CIA0rsM6hPWub6nmmBZFoz6S5LjcX1SDtNNZl_LKnexCnZnn5baIyltRCiLvcPO6KdrbK46Ew3GOoqyc_fj92jejCGx1ZIHQc2jMXhT1SAMMPsaiT75iSTCmrbFMiiVngmLf9';
const _garlicBread =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCJZXy7dkBOkiNT_oNP1zJiYFsp3Nj89SC6ThZl_fwjCGl0HnjJcFql8vLIBmQ7oonp8zn9pFXxyoWNXosEsyCfyfnXJi1FVFd3Nsuwggg48IiCm80gBIq9oRZHzKnwkWRC0lm136CuHm7-15XaUWY1-pFfefus06rFAaolnfRyqJ9POMvf103ImZB2X2i2u0I0AP_5tQdP-z5fRfpsArQgiM5HSFADD6nBBm-dKygQCtTNg7eu8xDp';

String productImageUrl(Product product, {String? existingImage}) {
  final savedImage = (existingImage ?? product.image).trim();
  if (savedImage.isNotEmpty) {
    return displayImageUrl(savedImage);
  }

  final name = product.name.toLowerCase();
  if (product.category == 'Pizzas') {
    if (name.contains('carnívora') || name.contains('extrema')) {
      return _meatPizza;
    }
    if (name.contains('hawaiana') || name.contains('tropical')) {
      return _andeanPizza;
    }
    if (name.contains('americana')) return _fourCheesePizza;
    return _apachePizza;
  }
  if (product.category == 'Bebidas' && name.contains('gaseosa')) {
    return _inkaCola;
  }
  if (product.category == 'Extras' && name.contains('ajo')) {
    return _garlicBread;
  }
  return '';
}
