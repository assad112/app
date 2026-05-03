import 'package:customer_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

enum OrderStatus {
  searchingDriver,
  driverNotified,
  noDriverFound,
  pendingReview,
  accepted,
  preparing,
  onTheWay,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String labelKey() {
    switch (this) {
      case OrderStatus.searchingDriver:
        return 'status.searchingDriver';
      case OrderStatus.driverNotified:
        return 'status.driverNotified';
      case OrderStatus.noDriverFound:
        return 'status.noDriverFound';
      case OrderStatus.pendingReview:
        return 'status.pendingReview';
      case OrderStatus.accepted:
        return 'status.accepted';
      case OrderStatus.preparing:
        return 'status.preparing';
      case OrderStatus.onTheWay:
        return 'status.onTheWay';
      case OrderStatus.delivered:
        return 'status.delivered';
      case OrderStatus.cancelled:
        return 'status.cancelled';
    }
  }

  Color tone() {
    switch (this) {
      case OrderStatus.searchingDriver:
      case OrderStatus.pendingReview:
        return AppColors.warning;
      case OrderStatus.driverNotified:
        return AppColors.brand;
      case OrderStatus.noDriverFound:
        return AppColors.error;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.onTheWay:
        return AppColors.brand;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  Color softTone() {
    switch (this) {
      case OrderStatus.searchingDriver:
      case OrderStatus.pendingReview:
        return AppColors.warningSoft;
      case OrderStatus.driverNotified:
        return AppColors.brandSoft;
      case OrderStatus.noDriverFound:
        return AppColors.errorSoft;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return AppColors.infoSoft;
      case OrderStatus.onTheWay:
        return AppColors.brandSoft;
      case OrderStatus.delivered:
        return AppColors.successSoft;
      case OrderStatus.cancelled:
        return AppColors.errorSoft;
    }
  }

  bool get canCancel {
    return this == OrderStatus.searchingDriver ||
        this == OrderStatus.driverNotified ||
        this == OrderStatus.noDriverFound ||
        this == OrderStatus.pendingReview ||
        this == OrderStatus.accepted ||
        this == OrderStatus.preparing;
  }

  String progressMessageKey() {
    switch (this) {
      case OrderStatus.searchingDriver:
        return 'statusMessage.searchingDriver';
      case OrderStatus.driverNotified:
        return 'statusMessage.driverNotified';
      case OrderStatus.noDriverFound:
        return 'statusMessage.noDriverFound';
      case OrderStatus.pendingReview:
        return 'statusMessage.pendingReview';
      case OrderStatus.accepted:
        return 'statusMessage.accepted';
      case OrderStatus.preparing:
        return 'statusMessage.preparing';
      case OrderStatus.onTheWay:
        return 'statusMessage.onTheWay';
      case OrderStatus.delivered:
        return 'statusMessage.delivered';
      case OrderStatus.cancelled:
        return 'statusMessage.cancelled';
    }
  }
}
