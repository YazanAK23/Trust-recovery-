import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:trust_app_updated/Pages/all_seasons/all_seasons.dart';
import 'package:trust_app_updated/Pages/products_by_season/products_by_season.dart';
import 'package:trust_app_updated/Pages/sub_categories/sub_categories.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';
import '../../Server/functions/functions.dart';
import '../../main.dart';

class SeasonWidget extends StatefulWidget {
  final name_ar, name_en, image, seasonImage;
  double height, width;
  int id = 0;
  SeasonWidget(
      {super.key,
      required this.name_ar,
      required this.name_en,
      required this.image,
      required this.width,
      required this.height,
      required this.id,
      required this.seasonImage});

  @override
  State<SeasonWidget> createState() => _SeasonWidgetState();
}

class _SeasonWidgetState extends State<SeasonWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          if (widget.id == 5) {
            NavigatorPushFunction(
                context,
                AllSeasons(
                  id: widget.id,
                  image: URLIMAGE + widget.seasonImage,
                  name_ar: widget.name_ar,
                  name_en: widget.name_en,
                ));
          } else {
            NavigatorPushFunction(
                context,
                ProductsBySeason(
                    name_ar: widget.name_ar,
                    name_en: widget.name_en,
                    season_image: URLIMAGE + widget.seasonImage,
                    image: URLIMAGE + widget.image,
                    season_id: widget.id));
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: widget.width == double.infinity ? null : widget.width,
              height: widget.height,
              constraints: BoxConstraints(
                maxWidth: 120,
                minWidth: 80,
              ),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Center(
                  child: SvgPicture.asset(
                widget.image,
                fit: BoxFit.contain,
                width: 55,
                height: 55,
              )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                locale.toString() == "ar" ? widget.name_ar : widget.name_en,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        ),
      ),
    );
  }
}
