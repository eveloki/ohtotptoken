//import * as $protobuf from "protobufjs";
import $protobuf from "@ohos/protobufjs";
import Long = require("long");
/** Namespace googleauth. */
export namespace googleauth {

    /** Properties of a MigrationPayload. */
    interface IMigrationPayload {

        /** MigrationPayload otpParameters */
        otpParameters?: (googleauth.MigrationPayload.IOtpParameters[]|null);

        /** MigrationPayload version */
        version?: (number|null);

        /** MigrationPayload batchSize */
        batchSize?: (number|null);

        /** MigrationPayload batchIndex */
        batchIndex?: (number|null);

        /** MigrationPayload batchId */
        batchId?: (number|null);
    }

    /** Represents a MigrationPayload. */
    class MigrationPayload implements IMigrationPayload {

        /**
         * Constructs a new MigrationPayload.
         * @param [properties] Properties to set
         */
        constructor(properties?: googleauth.IMigrationPayload);

        /** MigrationPayload otpParameters. */
        public otpParameters: googleauth.MigrationPayload.IOtpParameters[];

        /** MigrationPayload version. */
        public version: number;

        /** MigrationPayload batchSize. */
        public batchSize: number;

        /** MigrationPayload batchIndex. */
        public batchIndex: number;

        /** MigrationPayload batchId. */
        public batchId: number;

        /**
         * Creates a new MigrationPayload instance using the specified properties.
         * @param [properties] Properties to set
         * @returns MigrationPayload instance
         */
        public static create(properties?: googleauth.IMigrationPayload): googleauth.MigrationPayload;

        /**
         * Encodes the specified MigrationPayload message. Does not implicitly {@link googleauth.MigrationPayload.verify|verify} messages.
         * @param message MigrationPayload message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        public static encode(message: googleauth.IMigrationPayload, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Encodes the specified MigrationPayload message, length delimited. Does not implicitly {@link googleauth.MigrationPayload.verify|verify} messages.
         * @param message MigrationPayload message or plain object to encode
         * @param [writer] Writer to encode to
         * @returns Writer
         */
        public static encodeDelimited(message: googleauth.IMigrationPayload, writer?: $protobuf.Writer): $protobuf.Writer;

        /**
         * Decodes a MigrationPayload message from the specified reader or buffer.
         * @param reader Reader or buffer to decode from
         * @param [length] Message length if known beforehand
         * @returns MigrationPayload
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        public static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): googleauth.MigrationPayload;

        /**
         * Decodes a MigrationPayload message from the specified reader or buffer, length delimited.
         * @param reader Reader or buffer to decode from
         * @returns MigrationPayload
         * @throws {Error} If the payload is not a reader or valid buffer
         * @throws {$protobuf.util.ProtocolError} If required fields are missing
         */
        public static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): googleauth.MigrationPayload;

        /**
         * Verifies a MigrationPayload message.
         * @param message Plain object to verify
         * @returns `null` if valid, otherwise the reason why it is not
         */
        public static verify(message: { [k: string]: any }): (string|null);

        /**
         * Creates a MigrationPayload message from a plain object. Also converts values to their respective internal types.
         * @param object Plain object
         * @returns MigrationPayload
         */
        public static fromObject(object: { [k: string]: any }): googleauth.MigrationPayload;

        /**
         * Creates a plain object from a MigrationPayload message. Also converts values to other types if specified.
         * @param message MigrationPayload
         * @param [options] Conversion options
         * @returns Plain object
         */
        public static toObject(message: googleauth.MigrationPayload, options?: $protobuf.IConversionOptions): { [k: string]: any };

        /**
         * Converts this MigrationPayload to JSON.
         * @returns JSON object
         */
        public toJSON(): { [k: string]: any };

        /**
         * Gets the default type url for MigrationPayload
         * @param [typeUrlPrefix] your custom typeUrlPrefix(default "type.googleapis.com")
         * @returns The default type url
         */
        public static getTypeUrl(typeUrlPrefix?: string): string;
    }

    namespace MigrationPayload {

        /** Algorithm enum. */
        enum Algorithm {
            ALGORITHM_UNSPECIFIED = 0,
            SHA1 = 1,
            SHA256 = 2,
            SHA512 = 3,
            MD5 = 4
        }

        /** DigitCount enum. */
        enum DigitCount {
            DIGIT_COUNT_UNSPECIFIED = 0,
            SIX = 1,
            EIGHT = 2,
            SEVEN = 3
        }

        /** OtpType enum. */
        enum OtpType {
            OTP_TYPE_UNSPECIFIED = 0,
            HOTP = 1,
            TOTP = 2
        }

        /** Properties of an OtpParameters. */
        interface IOtpParameters {

            /** OtpParameters secret */
            secret?: (Uint8Array|null);

            /** OtpParameters name */
            name?: (string|null);

            /** OtpParameters issuer */
            issuer?: (string|null);

            /** OtpParameters algorithm */
            algorithm?: (googleauth.MigrationPayload.Algorithm|null);

            /** OtpParameters digits */
            digits?: (googleauth.MigrationPayload.DigitCount|null);

            /** OtpParameters type */
            type?: (googleauth.MigrationPayload.OtpType|null);

            /** OtpParameters counter */
            counter?: (number|Long|null);

            /** OtpParameters uniqueId */
            uniqueId?: (string|null);
        }

        /** Represents an OtpParameters. */
        class OtpParameters implements IOtpParameters {

            /**
             * Constructs a new OtpParameters.
             * @param [properties] Properties to set
             */
            constructor(properties?: googleauth.MigrationPayload.IOtpParameters);

            /** OtpParameters secret. */
            public secret: Uint8Array;

            /** OtpParameters name. */
            public name: string;

            /** OtpParameters issuer. */
            public issuer: string;

            /** OtpParameters algorithm. */
            public algorithm: googleauth.MigrationPayload.Algorithm;

            /** OtpParameters digits. */
            public digits: googleauth.MigrationPayload.DigitCount;

            /** OtpParameters type. */
            public type: googleauth.MigrationPayload.OtpType;

            /** OtpParameters counter. */
            public counter: (number|Long);

            /** OtpParameters uniqueId. */
            public uniqueId: string;

            /**
             * Creates a new OtpParameters instance using the specified properties.
             * @param [properties] Properties to set
             * @returns OtpParameters instance
             */
            public static create(properties?: googleauth.MigrationPayload.IOtpParameters): googleauth.MigrationPayload.OtpParameters;

            /**
             * Encodes the specified OtpParameters message. Does not implicitly {@link googleauth.MigrationPayload.OtpParameters.verify|verify} messages.
             * @param message OtpParameters message or plain object to encode
             * @param [writer] Writer to encode to
             * @returns Writer
             */
            public static encode(message: googleauth.MigrationPayload.IOtpParameters, writer?: $protobuf.Writer): $protobuf.Writer;

            /**
             * Encodes the specified OtpParameters message, length delimited. Does not implicitly {@link googleauth.MigrationPayload.OtpParameters.verify|verify} messages.
             * @param message OtpParameters message or plain object to encode
             * @param [writer] Writer to encode to
             * @returns Writer
             */
            public static encodeDelimited(message: googleauth.MigrationPayload.IOtpParameters, writer?: $protobuf.Writer): $protobuf.Writer;

            /**
             * Decodes an OtpParameters message from the specified reader or buffer.
             * @param reader Reader or buffer to decode from
             * @param [length] Message length if known beforehand
             * @returns OtpParameters
             * @throws {Error} If the payload is not a reader or valid buffer
             * @throws {$protobuf.util.ProtocolError} If required fields are missing
             */
            public static decode(reader: ($protobuf.Reader|Uint8Array), length?: number): googleauth.MigrationPayload.OtpParameters;

            /**
             * Decodes an OtpParameters message from the specified reader or buffer, length delimited.
             * @param reader Reader or buffer to decode from
             * @returns OtpParameters
             * @throws {Error} If the payload is not a reader or valid buffer
             * @throws {$protobuf.util.ProtocolError} If required fields are missing
             */
            public static decodeDelimited(reader: ($protobuf.Reader|Uint8Array)): googleauth.MigrationPayload.OtpParameters;

            /**
             * Verifies an OtpParameters message.
             * @param message Plain object to verify
             * @returns `null` if valid, otherwise the reason why it is not
             */
            public static verify(message: { [k: string]: any }): (string|null);

            /**
             * Creates an OtpParameters message from a plain object. Also converts values to their respective internal types.
             * @param object Plain object
             * @returns OtpParameters
             */
            public static fromObject(object: { [k: string]: any }): googleauth.MigrationPayload.OtpParameters;

            /**
             * Creates a plain object from an OtpParameters message. Also converts values to other types if specified.
             * @param message OtpParameters
             * @param [options] Conversion options
             * @returns Plain object
             */
            public static toObject(message: googleauth.MigrationPayload.OtpParameters, options?: $protobuf.IConversionOptions): { [k: string]: any };

            /**
             * Converts this OtpParameters to JSON.
             * @returns JSON object
             */
            public toJSON(): { [k: string]: any };

            /**
             * Gets the default type url for OtpParameters
             * @param [typeUrlPrefix] your custom typeUrlPrefix(default "type.googleapis.com")
             * @returns The default type url
             */
            public static getTypeUrl(typeUrlPrefix?: string): string;
        }
    }
}
